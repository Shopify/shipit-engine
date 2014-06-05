require 'pathname'
require 'fileutils'

class StackCommands < Commands

  def initialize(stack)
    @stack = stack
  end

  def fetch
    create_directories
    if Dir.exists?(@stack.git_path)
      git('fetch', 'origin', '--tags', @stack.branch, env: env, chdir: @stack.git_path)
    else
      git('clone', *modern_git_args, '--branch', @stack.branch, @stack.repo_git_url, @stack.git_path, env: env, chdir: @stack.deploys_path)
    end
  end

  def fetch_deployed_revision
    with_temporary_working_directory do |dir|
      spec = DeploySpec.new(dir, @stack.environment)
      outputs = spec.fetch_deployed_revision_steps.map do |command_line|
        Command.new(command_line, chdir: dir).run!
      end
      outputs.find(&:present?).try(:strip)
    end
  end

  def with_temporary_working_directory
    Dir.mktmpdir do |dir|
      git('clone', '--local', @stack.git_path, @stack.repo_name, chdir: dir).run!
      yield Pathname.new(File.join(dir, @stack.repo_name))
    end
  end

  def modern_git_args
    return [] unless git_version >= Gem::Version.new('1.7.10')
    %w(--single-branch)
  end

  def create_directories
    FileUtils.mkdir_p(@stack.deploys_path)
  end

end
