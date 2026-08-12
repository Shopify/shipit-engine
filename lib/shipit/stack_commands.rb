# frozen_string_literal: true

# rubocop:disable Lint/MissingCopEnableDirective, Lint/MissingSuper
require 'pathname'
require 'fileutils'
require 'open3'

module Shipit
  class StackCommands < Commands
    def initialize(stack)
      @stack = stack
    end

    def env
      super.merge(@stack.env)
    end

    def fetch_commit(commit)
      create_directories
      if valid_git_repository?(@stack.git_path)
        git('fetch', 'origin', *quiet_git_arg, '--tags', '--force', commit.sha, env:, chdir: @stack.git_path)
      else
        @stack.clear_git_cache!
        git_clone(@stack.repo_git_url, @stack.git_path, branch: @stack.branch, env:, chdir: @stack.deploys_path)
      end
    end

    def fetch
      create_directories
      if valid_git_repository?(@stack.git_path)
        git('fetch', 'origin', *quiet_git_arg, '--tags', '--force', @stack.branch, env:, chdir: @stack.git_path)
      else
        @stack.clear_git_cache!
        git_clone(@stack.repo_git_url, @stack.git_path, branch: @stack.branch, env:, chdir: @stack.deploys_path)
      end
    end

    def fetched?(commit)
      if valid_git_repository?(@stack.git_path)
        git('rev-parse', *quiet_git_arg, '--verify', "#{commit.sha}^{commit}", env:, chdir: @stack.git_path)
      else
        # When the stack's git cache is not valid, the commit is
        # NOT fetched. To keep the interface of this method
        # consistent, we must return a Shipit::Command whose #success?
        # method returns false - has a non-zero exit status. We utilize
        # the POSIX 'test' command with no arguments which should
        # always have an exit status of 1.
        Command.new('test', env:, chdir: @stack.deploys_path)
      end
    end

    def fetch_deployed_revision
      with_temporary_working_directory(commit: @stack.commits.reachable.last) do |dir|
        spec = DeploySpec::FileSystem.new(dir, @stack)
        outputs = spec.fetch_deployed_revision_steps!.map do |command_line|
          Command.new(command_line, env:, chdir: dir).run
        end
        outputs.find(&:present?).try(:strip)
      end
    end

    def build_cacheable_deploy_spec
      cacheable_deploy_spec(commit: nil)
    end

    # Evaluates the stack's cacheable deploy spec and returns it as a plain,
    # disk-detached Shipit::DeploySpec. Depending on Shipit.checkout_less_deploy_spec:
    #   :disabled -> checkout-based path (today's behavior)
    #   :enabled  -> git-object-database path; any doubt or error falls back
    #                to the checkout-based path
    #   :shadow   -> checkout-based result is authoritative and returned; the
    #                git-object path additionally runs and any divergence is
    #                reported, but never raises
    def cacheable_deploy_spec(commit: nil)
      mode = Shipit.checkout_less_deploy_spec
      return checkout_cacheable_deploy_spec(commit).first if mode == :disabled || commit.nil?

      case mode
      when :enabled
        begin
          spec, = git_object_cacheable_deploy_spec(commit)
          notify_checkout_less(:hit)
          spec
        rescue DeploySpec::GitObjectFileSystem::FallbackRequired => e
          notify_checkout_less(:fallback, reason: e.reason, detail: e.detail)
          checkout_cacheable_deploy_spec(commit).first
        rescue Command::Error, SystemCallError => e
          notify_checkout_less(:fallback, reason: :git_error, detail: e.message)
          checkout_cacheable_deploy_spec(commit).first
        rescue StandardError => e
          notify_checkout_less(:fallback, reason: :unexpected_error, detail: "#{e.class}: #{e.message}")
          checkout_cacheable_deploy_spec(commit).first
        end
      when :shadow
        old_spec, old_root = checkout_cacheable_deploy_spec(commit)
        begin
          new_spec, new_root = git_object_cacheable_deploy_spec(commit)
          # Specs legitimately embed their (ephemeral) evaluation directory in
          # some values (e.g. release-gem <dir>/x.gemspec), so both sides are
          # compared with their own root normalized out.
          old_config = normalize_spec_config(old_spec.config, old_root)
          new_config = normalize_spec_config(new_spec.config, new_root)
          if old_config == new_config
            notify_checkout_less(:hit)
          else
            differing = (old_config.keys | new_config.keys)
                        .reject { |key| old_config[key] == new_config[key] }
            notify_checkout_less(:shadow_mismatch, detail: differing.first(5).join(','))
          end
        rescue StandardError => e
          notify_checkout_less(:fallback, reason: :shadow_error, detail: "#{e.class}: #{e.message}")
        end
        old_spec
      end
    end

    # Raw blob content at a commit, bypassing Shipit::Command: Command runs
    # through a PTY, which rewrites newlines and is unsafe for raw bytes and
    # NUL-delimited output. Local object-database reads need no env/auth.
    def git_read_object(sha, repo_rel_path)
      git_read('cat-file', 'blob', "#{sha}:#{repo_rel_path}")
    end

    # Directory listing at a commit: { name => mode }. "" lists the root
    # tree. The trailing slash on the pathspec lists the directory's
    # children rather than the directory entry itself.
    def git_ls_dir(sha, repo_rel_dir)
      args = ['ls-tree', '-z', sha]
      args += ['--', "#{repo_rel_dir}/"] unless repo_rel_dir.empty?
      output = git_read(*args)
      output.split("\0").each_with_object({}) do |record, listing|
        next if record.empty?

        meta, name = record.split("\t", 2) # limit 2: filenames may contain tabs
        mode = meta.split(' ', 3).first
        listing[File.basename(name)] = mode
      end
    end

    def with_temporary_working_directory(commit: nil, recursive: true)
      commit ||= @stack.last_deployed_commit.presence || @stack.commits.reachable.last

      if !commit || !fetched?(commit).tap(&:run).success?
        @stack.acquire_git_cache_lock do
          fetch.run! unless fetched?(commit).tap(&:run).success?
        end
      end

      git_args = []
      git_args << '--recursive' if recursive
      Dir.mktmpdir do |dir|
        git(
          'clone', @stack.git_path, @stack.repo_name,
          *git_args, '--origin', 'cache',
          chdir: dir
        ).run!

        git_dir = File.join(dir, @stack.repo_name)
        if commit
          git(
            '-c',
            'advice.detachedHead=false',
            'checkout',
            *quiet_git_arg,
            commit.sha,
            chdir: git_dir
          ).run!
        end
        yield Pathname.new(git_dir)
      end
    end

    def valid_git_repository?(path)
      path.exist? &&
        !path.empty? &&
        git_cmd_succeeds?(path)
    end

    def git_cmd_succeeds?(path)
      git("rev-parse", "--git-dir", chdir: path)
        .tap(&:run)
        .success?
    end

    def git_clone(url, path, branch: 'main', **kwargs)
      git('clone', *quiet_git_arg, *modern_git_args, '--recursive', '--branch', branch, url, path, **kwargs)
    end

    def modern_git_args
      return [] unless git_version >= Gem::Version.new('1.7.10')

      %w[--single-branch]
    end

    def create_directories
      FileUtils.mkdir_p(@stack.deploys_path)
    end

    def quiet_git_arg
      Shipit.git_progress_output ? [] : ['--quiet']
    end

    private

    # Both path methods return [spec, evaluation_root] so shadow mode can
    # normalize root-dependent values out of the comparison.
    def checkout_cacheable_deploy_spec(commit)
      with_temporary_working_directory(commit:, recursive: false) do |dir|
        [DeploySpec::FileSystem.new(dir, @stack).cacheable, dir.to_s]
      end
    end

    def git_object_cacheable_deploy_spec(commit)
      unless fetched?(commit).tap(&:run).success?
        @stack.acquire_git_cache_lock do
          fetch.run! unless fetched?(commit).tap(&:run).success?
        end
      end

      Dir.mktmpdir do |dir|
        [DeploySpec::GitObjectFileSystem.new(dir, @stack, commands: self, sha: commit.sha).cacheable, dir.to_s]
      end
    end

    def normalize_spec_config(value, root)
      case value
      when String then value.gsub(root, '$SPEC_ROOT')
      when Hash then value.transform_values { |nested| normalize_spec_config(nested, root) }
      when Array then value.map { |nested| normalize_spec_config(nested, root) }
      else value
      end
    end

    def git_read(*args)
      output, error, status = Open3.capture3('git', *args, chdir: @stack.git_path.to_s, binmode: true)
      raise Command::Failed.new("git #{args.first} failed: #{error.strip}", status.exitstatus) unless status.success?

      output
    end

    def notify_checkout_less(event, reason: nil, detail: nil)
      payload = { stack_id: @stack.id, event:, reason:, detail: }.compact
      ActiveSupport::Notifications.instrument('checkout_less_deploy_spec.shipit', payload)
      if event == :hit
        Rails.logger.debug { "[checkout_less_deploy_spec] hit stack=#{@stack.id}" }
      else
        Rails.logger.warn(
          "[checkout_less_deploy_spec] #{event} stack=#{@stack.id} reason=#{reason} detail=#{detail}"
        )
      end
    end

    def github
      Shipit.github(organization: @stack.repository.owner)
    end
  end
end
