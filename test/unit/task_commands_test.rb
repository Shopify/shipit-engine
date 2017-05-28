require 'test_helper'

class TaskCommandsTest < ActiveSupport::TestCase
  def setup
    @stack = stacks(:shipit)
    @task = tasks(:shipit_restart)
    @commands = TaskCommands.new(@task)
    @deploy_spec = stub(
      dependencies_steps!: ['bundle install --some-args'],
      deploy_steps!: ['bundle exec cap $ENVIRONMENT deploy'],
      rollback_steps!: ['bundle exec cap $ENVIRONMENT deploy:rollback'],
      machine_env: {'GLOBAL' => '1'},
      directory: nil,
    )
    @commands.stubs(:deploy_spec).returns(@deploy_spec)

    StackCommands.stubs(git_version: Gem::Version.new('1.8.4.3'))
  end

  test "#fetch calls git fetch if repository cache already exist" do
    Dir.expects(:exist?).with(@stack.git_path).returns(true)
    command = @commands.fetch
    assert_equal %w(git fetch origin --tags master), command.args
  end

  test "#fetch calls git fetch in git_path directory if repository cache already exist" do
    Dir.expects(:exist?).with(@stack.git_path).returns(true)
    command = @commands.fetch
    assert_equal @stack.git_path, command.chdir
  end

  test "#fetch calls git clone if repository cache do not exist" do
    Dir.expects(:exist?).with(@stack.git_path).returns(false)
    command = @commands.fetch
    expected = %W(git clone --single-branch --recursive --branch master #{@stack.repo_git_url} #{@stack.git_path})
    assert_equal expected, command.args
  end

  test "#fetch does not use --single-branch if git is outdated" do
    Dir.expects(:exist?).with(@stack.git_path).returns(false)
    StackCommands.stubs(git_version: Gem::Version.new('1.7.2.30'))
    command = @commands.fetch
    expected = %W(git clone --recursive --branch master #{@stack.repo_git_url} #{@stack.git_path})
    assert_equal expected, command.args
  end

  test "#fetch calls git fetch in base_path directory if repository cache do not exist" do
    Dir.expects(:exist?).with(@stack.git_path).returns(false)
    command = @commands.fetch
    assert_equal @stack.deploys_path, command.chdir
  end

  test "#fetch merges Shipit.env in ENVIRONMENT" do
    Shipit.stubs(:env).returns("SPECIFIC_CONFIG" => 5)
    command = @commands.fetch
    assert_equal 5, command.env["SPECIFIC_CONFIG"]
  end

  test "#clone clones the repository cache into the working directory" do
    command = @commands.clone
    assert_equal ['git', 'clone', '--local', @stack.git_path, @task.working_directory], command.args
  end

  test "#clone clones the repository cache from the deploys_path" do
    command = @commands.clone
    assert_equal @stack.deploys_path, command.chdir
  end

  test "#checkout checks out the deployed commit" do
    command = @commands.checkout(@task.until_commit)
    assert_equal ['git', 'checkout', @task.until_commit.sha], command.args
  end

  test "#checkout checks out the deployed commit from the working directory" do
    command = @commands.checkout(@task.until_commit)
    assert_equal @task.working_directory, command.chdir
  end

  test "#perform calls cap $environment deploy" do
    commands = @commands.perform
    assert_equal 1, commands.length
    command = commands.first
    assert_equal ['bundle exec cap $ENVIRONMENT deploy'], command.args
  end

  test "#perform calls cap $environment deploy:rollback for a rollback of a capistrano stack" do
    @rollback = @task.build_rollback
    @rollback.save!
    @commands = Commands.for(@rollback)
    @commands.stubs(:deploy_spec).returns(@deploy_spec)

    steps = @commands.perform
    assert_equal 1, steps.length
    step = steps.first
    assert_equal ['bundle exec cap $ENVIRONMENT deploy:rollback'], step.args
  end

  test "#perform calls cap $environment deploy from the working_directory" do
    commands = @commands.perform
    assert_equal 1, commands.length
    command = commands.first
    assert_equal @task.working_directory, command.chdir
  end

  test "the working_directory can be overriten in the spec" do
    @deploy_spec.stubs(:directory).returns('my_directory')
    commands = @commands.perform
    assert_equal 1, commands.length
    command = commands.first
    assert_equal File.join(@task.working_directory, 'my_directory'), command.chdir
  end

  test "#perform calls cap $environment deploy with the SHA in the environment" do
    commands = @commands.perform
    assert_equal 1, commands.length
    command = commands.first
    assert_equal @task.until_commit.sha, command.env['SHA']
  end

  test "#perform calls cap $environment deploy with the SHIPIT_LINK in the environment" do
    commands = @commands.perform
    assert_equal 1, commands.length
    command = commands.first
    assert_equal "http://shipit.com/shopify/shipit-engine/production/deploys/#{@task.id}", command.env['SHIPIT_LINK']
  end

  test "#perform calls cap $environment deploy with the LAST_DEPLOYED_SHA in the environment" do
    commands = @commands.perform
    assert_equal 1, commands.length
    command = commands.first
    assert_equal @task.stack.last_deployed_commit.sha, command.env['LAST_DEPLOYED_SHA']
  end

  test "#perform transliterates the user name" do
    @task.user = User.new(login: 'Sirupsen', name: "Simon Hørup Eskildsen")
    commands = @commands.perform
    assert_equal 1, commands.length
    command = commands.first
    assert_equal "Sirupsen (Simon Horup Eskildsen) via Shipit", command.env['USER']
  end

  test "#perform calls cap $environment deploy with the ENVIRONMENT in the environment" do
    commands = @commands.perform
    assert_equal 1, commands.length
    command = commands.first
    assert_equal @stack.environment, command.env['ENVIRONMENT']
  end

  test "#perform merges Shipit.env in ENVIRONMENT" do
    Shipit.stubs(:env).returns("SPECIFIC_CONFIG" => 5)
    assert_equal 5, @commands.env["SPECIFIC_CONFIG"]
  end

  test "#perform merges shipit.yml machine_env in ENVIRONMENT" do
    assert_equal '1', @commands.env['GLOBAL']
  end

  test "#install_dependencies calls bundle install" do
    commands = @commands.install_dependencies
    assert_equal 1, commands.length
    assert_equal ['bundle install --some-args'], commands.first.args
  end

  test "#install_dependencies merges Shipit.env in ENVIRONMENT" do
    Shipit.stubs(:env).returns("SPECIFIC_CONFIG" => 5)
    command = @commands.install_dependencies.first
    assert_equal 5, command.env["SPECIFIC_CONFIG"]
  end

  test "#install_dependencies merges machine_env in ENVIRONMENT" do
    command = @commands.install_dependencies.first
    assert_equal '1', command.env['GLOBAL']
  end

  test "the deploy's `env` is merged in ENVIRONMENT" do
    @task.env = {'FOO' => 'BAR'}
    command = @commands.install_dependencies.first
    assert_equal 'BAR', command.env['FOO']
  end
end
