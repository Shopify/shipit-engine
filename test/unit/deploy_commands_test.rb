require 'test_helper'

class DeployCommandsTest < ActiveSupport::TestCase
  def setup
    @stack = stacks(:shipit)
    @deploy = deploys(:shipit_pending)
    @commands = DeployCommands.new(@deploy)
    @deploy_spec = stub(
      dependencies_steps: ['bundle install --some-args'],
      deploy_steps: ['bundle exec cap $ENVIRONMENT deploy'],
      machine_env: {'GLOBAL' => '1'},
    )
    @commands.stubs(:deploy_spec).returns(@deploy_spec)
    StackCommands.stubs(git_version: Gem::Version.new('1.8.4.3'))
  end

  test "#fetch calls git fetch if repository cache already exist" do
    Dir.expects(:exists?).with(@stack.git_path).returns(true)
    command = @commands.fetch
    assert_equal %w(git fetch origin --tags master), command.args
  end

  test "#fetch calls git fetch in git_path directory if repository cache already exist" do
    Dir.expects(:exists?).with(@stack.git_path).returns(true)
    command = @commands.fetch
    assert_equal @stack.git_path, command.chdir
  end

  test "#fetch calls git clone if repository cache do not exist" do
    Dir.expects(:exists?).with(@stack.git_path).returns(false)
    command = @commands.fetch
    assert_equal ['git', 'clone', '--single-branch', '--branch', 'master', @stack.repo_git_url, @stack.git_path], command.args
  end

  test "#fetch does not use --single-branch if git is outdated" do
    Dir.expects(:exists?).with(@stack.git_path).returns(false)
    StackCommands.stubs(git_version: Gem::Version.new('1.7.2.30'))
    command = @commands.fetch
    assert_equal ['git', 'clone', '--branch', 'master', @stack.repo_git_url, @stack.git_path], command.args
  end

  test "#fetch calls git fetch in base_path directory if repository cache do not exist" do
    Dir.expects(:exists?).with(@stack.git_path).returns(false)
    command = @commands.fetch
    assert_equal @stack.deploys_path, command.chdir
  end

  test "#fetch merges Settings.env in ENVIRONMENT" do
    Settings.stubs(:[]).with('env').returns("SPECIFIC_CONFIG" => 5)
    command = @commands.fetch
    assert_equal 5, command.env["SPECIFIC_CONFIG"]
  end

  test "#clone clones the repository cache into the working directory" do
    command = @commands.clone
    assert_equal ['git', 'clone', '--local', @stack.git_path, @deploy.working_directory], command.args
  end

  test "#clone clones the repository cache from the deploys_path" do
    command = @commands.clone
    assert_equal @stack.deploys_path, command.chdir
  end

  test "#remote_prune calls git remote prune origin" do
    command = @commands.remote_prune
    assert_equal ['git', 'remote', 'prune', 'origin'], command.args
  end

  test "#checkout checks out the deployed commit" do
    command = @commands.checkout(@deploy.until_commit)
    assert_equal ['git', 'checkout', '-q', @deploy.until_commit.sha], command.args
  end

  test "#checkout checks out the deployed commit from the working directory" do
    command = @commands.checkout(@deploy.until_commit)
    assert_equal @deploy.working_directory, command.chdir
  end

  test "#deploy calls cap $environment deploy" do
    commands = @commands.deploy(@deploy.until_commit)
    assert_equal 1, commands.length
    command = commands.first
    assert_equal ['bundle exec cap $ENVIRONMENT deploy'], command.args
  end

  test "#deploy calls cap $environment deploy from the working_directory" do
    commands = @commands.deploy(@deploy.until_commit)
    assert_equal 1, commands.length
    command = commands.first
    assert_equal @deploy.working_directory, command.chdir
  end

  test "#deploy calls cap $environment deploy with the SHA in the environment" do
    commands = @commands.deploy(@deploy.until_commit)
    assert_equal 1, commands.length
    command = commands.first
    assert_equal @deploy.until_commit.sha, command.env['SHA']
  end

  test "#deploy transliterates the user name" do
    @deploy.user = User.new(login: 'Sirupsen', name: "Simon Hørup Eskildsen")
    commands = @commands.deploy(@deploy.until_commit)
    assert_equal 1, commands.length
    command = commands.first
    assert_equal "Sirupsen (Simon Horup Eskildsen) via Shipit 2", command.env['USER']
  end

  test "#deploy calls cap $environment deploy with the ENVIRONMENT in the environment" do
    commands = @commands.deploy(@deploy.until_commit)
    assert_equal 1, commands.length
    command = commands.first
    assert_equal @stack.environment, command.env['ENVIRONMENT']
  end

  test "#deploy merges Settings.env in ENVIRONMENT" do
    Settings.stubs(:[]).with('env').returns("SPECIFIC_CONFIG" => 5)
    command = @commands.deploy(@deploy.until_commit).first
    assert_equal 5, command.env["SPECIFIC_CONFIG"]
  end

  test "#deploy merges shipit.yml machine_env in ENVIRONMENT" do
    command = @commands.deploy(@deploy.until_commit).first
    assert_equal '1', command.env['GLOBAL']
  end

  test "#install_dependencies calls bundle install" do
    commands = @commands.install_dependencies
    assert_equal 1, commands.length
    assert_equal ['bundle install --some-args'], commands.first.args
  end

  test "#install_dependencies merges Settings.env in ENVIRONMENT" do
    Settings.stubs(:[]).with('env').returns("SPECIFIC_CONFIG" => 5)
    command = @commands.install_dependencies.first
    assert_equal 5, command.env["SPECIFIC_CONFIG"]
  end

  test "#install_dependencies merges machine_env in ENVIRONMENT" do
    command = @commands.install_dependencies.first
    assert_equal '1', command.env['GLOBAL']
  end
end
