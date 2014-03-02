require 'test_helper'

class DeployCommandsTest < ActiveSupport::TestCase
  def setup
    @stack = stacks(:shipit)
    @deploy = deploys(:shipit_pending)
    @commands = DeployCommands.new(@deploy)
  end

  test "#fetch call git fetch if repository cache already exist" do
    Dir.expects(:exists?).with(@stack.git_path).returns(true)
    command = @commands.fetch
    assert_equal %w(git fetch), command.args
  end

  test "#fetch call git fetch in git_path directory if repository cache already exist" do
    Dir.expects(:exists?).with(@stack.git_path).returns(true)
    command = @commands.fetch
    assert_equal @stack.git_path, command.chdir
  end

  test "#fetch call git clone if repository cache do not exist" do
    Dir.expects(:exists?).with(@stack.git_path).returns(false)
    command = @commands.fetch
    assert_equal ['git', 'clone', @stack.repo_git_url, @stack.git_path], command.args
  end

  test "#fetch call git fetch in base_path directory if repository cache do not exist" do
    Dir.expects(:exists?).with(@stack.git_path).returns(false)
    command = @commands.fetch
    assert_equal @stack.deploys_path, command.chdir
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
    command = @commands.deploy(@deploy.until_commit)
    assert_equal ['bundle', 'exec', 'cap', @stack.environment, 'deploy'], command.args
  end

  test "#deploy call cap $environment deploy from the working_directory" do
    command = @commands.deploy(@deploy.until_commit)
    assert_equal @deploy.working_directory, command.chdir
  end

  test "#deploy call cap $environment deploy with the SHA in the environment" do
    command = @commands.deploy(@deploy.until_commit)
    assert_equal @deploy.until_commit.sha, command.env['SHA']
  end

  test "#bundle_install call bundle install" do
    command = @commands.bundle_install
    args = ["bundle", "install", "--frozen", "--path=#{DeployCommands::BUNDLE_PATH}", "--retry=2",
        "--without=default:production:development:test:staging:benchmark:debug"]
    assert_equal args, command.args
  end

end
