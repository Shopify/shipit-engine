# frozen_string_literal: true

require 'test_helper'
require 'open3'

module Shipit
  class DeploySpec
    class GitObjectFileSystemTest < ActiveSupport::TestCase
      setup do
        @stack = shipit_stacks(:shipit)
        @tmpdirs = []
      end

      teardown do
        @tmpdirs.each { |dir| FileUtils.rm_rf(dir) }
      end

      # --- Golden equivalence: checkout-based and git-object-based specs match ---

      test "golden: env-specific shipit.production.yml" do
        assert_golden('shipit.production.yml' => "deploy:\n  override:\n    - echo deploy\n")
      end

      test "golden: bare shipit.yml produces the same warning stub on both paths" do
        # respect_bare_shipit_file replaces bare configs with a warning stub;
        # both paths must short-circuit identically.
        assert_golden('shipit.yml' => "deploy:\n  override:\n    - echo bare\n")
      end

      test "golden: shipit.<env>.yml takes priority over bare shipit.yml" do
        assert_golden(
          'shipit.yml' => "deploy:\n  override:\n    - echo wrong\n",
          'shipit.production.yml' => "deploy:\n  override:\n    - echo right\n"
        )
      end

      test "golden: .shipit/ variants" do
        assert_golden('.shipit/production.yml' => "deploy:\n  override:\n    - echo dotdir\n")
      end

      test "golden: no config at all, pure discovery" do
        assert_golden(
          'Gemfile' => "source 'https://rubygems.org'\n",
          'Gemfile.lock' => "GEM\n"
        )
      end

      test "golden: inherit_from in same directory" do
        assert_golden(
          'shipit.production.yml' => "inherit_from: base.yml\ndeploy:\n  override:\n    - echo child\n",
          'base.yml' => "machine:\n  environment:\n    FOO: bar\n"
        )
      end

      test "golden: inherit_from three levels deep across directories" do
        assert_golden(
          'shipit.production.yml' => "inherit_from: configs/a.yml\n",
          'configs/a.yml' => "inherit_from: b.yml\ndeploy:\n  override:\n    - echo a\n",
          'configs/b.yml' => "machine:\n  environment:\n    DEPTH: '3'\n"
        )
      end

      test "golden: machine.directory re-roots discovery" do
        assert_golden(
          'shipit.production.yml' => "machine:\n  directory: frontend\n",
          'frontend/package.json' => '{"private": true}',
          'frontend/yarn.lock' => "# yarn\n"
        )
      end

      test "golden: gemspec glob with zero, one and many matches" do
        assert_golden('README.md' => "no gemspecs\n")
        assert_golden('foo.gemspec' => "Gem::Specification.new\n")
        assert_golden(
          'a.gemspec' => "Gem::Specification.new\n",
          'b.gemspec' => "Gem::Specification.new\n"
        )
      end

      test "golden: gemspec filename with a space" do
        assert_golden('my gem.gemspec' => "Gem::Specification.new\n")
      end

      test "golden: package.json private false publishes" do
        assert_golden('package.json' => '{"name": "x", "private": false, "version": "1.0.0"}')
      end

      test "golden: lerna.json content is read" do
        assert_golden(
          'package.json' => '{"private": true}',
          'lerna.json' => '{"version": "1.2.3"}'
        )
      end

      test "golden: .gitattributes in an unrelated subtree does not interfere" do
        assert_golden(
          'shipit.production.yml' => "deploy:\n  override:\n    - echo ok\n",
          'vendor/.gitattributes' => "*.png binary\n",
          'vendor/thing.txt' => "x\n"
        )
      end

      # --- Fallback guards ---

      test "fallback: inherit_from escaping the repository" do
        repo, sha = make_repo('shipit.production.yml' => "inherit_from: ../../evil.yml\n")
        error = assert_fallback(repo, sha)
        assert_equal :escape, error.reason
      end

      test "fallback: absolute inherit_from path" do
        repo, sha = make_repo('shipit.production.yml' => "inherit_from: /etc/passwd\n")
        error = assert_fallback(repo, sha)
        assert_equal :escape, error.reason
      end

      test "fallback: inherit_from cycle hits the depth cap" do
        repo, sha = make_repo(
          'shipit.production.yml' => "inherit_from: a.yml\n",
          'a.yml' => "inherit_from: b.yml\n",
          'b.yml' => "inherit_from: a.yml\n"
        )
        error = assert_fallback(repo, sha)
        assert_equal :inherit_depth, error.reason
      end

      test "fallback: symlinked config file" do
        repo, sha = make_repo('real.yml' => "deploy:\n  override:\n    - echo x\n") do |dir|
          File.symlink('real.yml', dir.join('shipit.production.yml'))
        end
        error = assert_fallback(repo, sha)
        assert_equal :symlink, error.reason
      end

      test "fallback: symlinked intermediate directory" do
        repo, sha = make_repo(
          'shipit.production.yml' => "machine:\n  directory: linkdir\n",
          'realdir/Gemfile' => "source 'https://rubygems.org'\n"
        ) do |dir|
          File.symlink('realdir', dir.join('linkdir'))
        end
        error = assert_fallback(repo, sha)
        assert_equal :symlink, error.reason
      end

      test "fallback: submodule gitlink on an accessed path" do
        repo, base_sha = make_repo('shipit.production.yml' => "machine:\n  directory: sub\n")
        # Record a gitlink entry (mode 160000) without needing a real submodule.
        git(repo, 'update-index', '--add', '--cacheinfo', "160000,#{base_sha},sub")
        git(repo, 'commit', '-qm', 'add gitlink')
        sha = git_out(repo, 'rev-parse', 'HEAD')
        error = assert_fallback(repo, sha)
        assert_equal :submodule, error.reason
      end

      test "fallback: regular file as intermediate path component" do
        repo, sha = make_repo(
          'shipit.production.yml' => "machine:\n  directory: Gemfile/sub\n",
          'Gemfile' => "source 'https://rubygems.org'\n"
        )
        error = assert_fallback(repo, sha)
        assert_equal :file_in_path, error.reason
      end

      test "fallback: .gitattributes at the repository root" do
        repo, sha = make_repo(
          'shipit.production.yml' => "deploy:\n  override:\n    - echo x\n",
          '.gitattributes' => "* text=auto\n"
        )
        error = assert_fallback(repo, sha)
        assert_equal :gitattributes, error.reason
      end

      test "fallback: .gitattributes inside machine.directory" do
        repo, sha = make_repo(
          'shipit.production.yml' => "machine:\n  directory: app\n",
          'app/.gitattributes' => "*.rb eol=lf\n",
          'app/Gemfile' => "source 'https://rubygems.org'\n"
        )
        error = assert_fallback(repo, sha)
        assert_equal :gitattributes, error.reason
      end

      # --- Idempotency ---

      test "repeat access to the same file reads the object database once" do
        repo, sha = make_repo('package.json' => '{"private": true, "version": "1.0.0"}')
        commands = commands_for(repo)
        reads = Hash.new(0)
        original = commands.method(:git_read_object)
        commands.define_singleton_method(:git_read_object) do |commit_sha, path|
          reads[path] += 1
          original.call(commit_sha, path)
        end

        Dir.mktmpdir do |dir|
          fs = GitObjectFileSystem.new(dir, @stack, commands:, sha:)
          fs.file('package.json').read
          fs.file('package.json').exist?
          fs.file('package.json').read
        end

        assert_equal 1, reads['package.json']
      end

      private

      def assert_golden(files)
        repo, sha = make_repo(files)
        expected, expected_root = checkout_config(repo, sha)
        actual, actual_root = git_object_config(repo, sha)
        assert_equal normalize(expected, expected_root), normalize(actual, actual_root)
      end

      # Specs embed their evaluation directory in some values (e.g.
      # release-gem <dir>/x.gemspec); normalize both roots out, mirroring
      # what shadow mode does in production.
      def normalize(value, root)
        case value
        when String then value.gsub(root, '$ROOT')
        when Hash then value.transform_values { |nested| normalize(nested, root) }
        when Array then value.map { |nested| normalize(nested, root) }
        else value
        end
      end

      def assert_fallback(repo, sha)
        assert_raises(GitObjectFileSystem::FallbackRequired) do
          git_object_config(repo, sha)
        end
      end

      def make_repo(files)
        dir = Pathname(Dir.mktmpdir)
        @tmpdirs << dir
        git(dir, 'init', '-q', '-b', 'main')
        git(dir, 'config', 'user.email', 'test@example.com')
        git(dir, 'config', 'user.name', 'Test')
        git(dir, 'config', 'commit.gpgsign', 'false')
        files.each do |path, content|
          full = dir.join(path)
          full.dirname.mkpath
          File.write(full, content)
        end
        yield dir if block_given?
        git(dir, 'add', '-A')
        git(dir, 'commit', '-qm', 'test commit')
        [dir, git_out(dir, 'rev-parse', 'HEAD')]
      end

      def git(dir, *args)
        _, error, status = Open3.capture3('git', *args, chdir: dir.to_s)
        raise "git #{args.join(' ')} failed: #{error}" unless status.success?
      end

      def git_out(dir, *args)
        output, error, status = Open3.capture3('git', *args, chdir: dir.to_s)
        raise "git #{args.join(' ')} failed: #{error}" unless status.success?

        output.strip
      end

      def checkout_config(repo, sha)
        Dir.mktmpdir do |dir|
          workdir = File.join(dir, 'wc')
          git(Pathname(dir), 'clone', '-q', repo.to_s, workdir)
          git(Pathname(workdir), 'checkout', '-q', sha)
          [FileSystem.new(workdir, @stack).cacheable.config, workdir]
        end
      end

      def git_object_config(repo, sha)
        commands = commands_for(repo)
        Dir.mktmpdir do |dir|
          [GitObjectFileSystem.new(dir, @stack, commands:, sha:).cacheable.config, dir]
        end
      end

      def commands_for(repo)
        stack = @stack
        stack.stubs(:git_path).returns(repo)
        StackCommands.new(stack)
      end
    end
  end
end
