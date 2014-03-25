require 'test_helper'

class DeployCommandsTest < ActiveSupport::TestCase
  def setup
    @stack = stacks(:shipit)
    @deploy = deploys(:shipit_pending)
    @commands = DeployCommands.new(@deploy)
    @deploy_spec = stub(
      dependencies_steps: ['bundle install --some-args'],
      deploy_steps: ['bundle exec cap $ENVIRONMENT deploy'],
    )
    @commands.stubs(:deploy_spec).returns(@deploy_spec)
  end

  test "#fetch call git fetch if repository cache already exist" do
    Dir.expects(:exists?).with(@stack.git_path).returns(true)
    command = @commands.fetch
    assert_equal %w(git fetch origin master), command.args
  end

  test "#fetch call git fetch in git_path directory if repository cache already exist" do
    Dir.expects(:exists?).with(@stack.git_path).returns(true)
    command = @commands.fetch
    assert_equal @stack.git_path, command.chdir
  end

  test "#fetch call git clone if repository cache do not exist" do
    Dir.expects(:exists?).with(@stack.git_path).returns(false)
    command = @commands.fetch
    assert_equal ['git', 'clone', '--branch', 'master', @stack.repo_git_url, @stack.git_path], command.args
  end

  test "#fetch call git fetch in base_path directory if repository cache do not exist" do
    Dir.expects(:exists?).with(@stack.git_path).returns(false)
    command = @commands.fetch
    assert_equal @stack.deploys_path, command.chdir
  end

  test "#fetch merges Settings.env in ENVIRONMENT" do
    Settings.stubs(:[]).with('env').returns("SPECIFIC_CONFIG" => 5)
    command = @commands.fetch
    assert_equal 5, command.env["SPECIFIC_CONFIG"]
  end

  test "#clone clone the repository cache into the working directory" do
    command = @commands.clone
    assert_equal ['git', 'clone', '--local', @stack.git_path, @deploy.working_directory], command.args
  end

  test "#clone clone the repository cache from the deploys_path" do
    command = @commands.clone
    assert_equal @stack.deploys_path, command.chdir
  end

  test "#checkout checkout the deployed commit" do
    command = @commands.checkout(@deploy.until_commit)
    assert_equal ['git', 'checkout', '-q', @deploy.until_commit.sha], command.args
  end

  test "#checkout checkout the deployed commit from the working directory" do
    command = @commands.checkout(@deploy.until_commit)
    assert_equal @deploy.working_directory, command.chdir
  end

  test "#deploy call cap $environment deploy" do
    commands = @commands.deploy(@deploy.until_commit)
    assert_equal 1, commands.length
    command = commands.first
    assert_equal ['bundle exec cap $ENVIRONMENT deploy'], command.args
  end

  test "#deploy call cap $environment deploy from the working_directory" do
    commands = @commands.deploy(@deploy.until_commit)
    assert_equal 1, commands.length
    command = commands.first
    assert_equal @deploy.working_directory, command.chdir
  end

  test "#deploy call cap $environment deploy with the SHA in the environment" do
    commands = @commands.deploy(@deploy.until_commit)
    assert_equal 1, commands.length
    command = commands.first
    assert_equal @deploy.until_commit.sha, command.env['SHA']
  end

  test "#deploy call cap $environment deploy with the ENVIRONMENT in the environment" do
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

  test "#install_dependencies call bundle install" do
    commands = @commands.install_dependencies
    assert_equal 1, commands.length
    assert_equal ['bundle install --some-args'], commands.first.args
  end

  test "#install_dependencies merges Settings.env in ENVIRONMENT" do
    Settings.stubs(:[]).with('env').returns("SPECIFIC_CONFIG" => 5)
    command = @commands.install_dependencies.first
    assert_equal 5, command.env["SPECIFIC_CONFIG"]
  end

end
