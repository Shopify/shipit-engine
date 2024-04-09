# frozen_string_literal: true

require 'test_helper'

module Shipit
  class DeployCommandsTest < ActiveSupport::TestCase
    def setup
      @deploy = shipit_deploys(:shipit_pending)
      @stack = @deploy.stack
      @stack.stubs(:clear_git_cache!)
      @commands = DeployCommands.new(@deploy)
      @deploy_spec = stub(
        dependencies_steps!: ['bundle install --some-args'],
        deploy_steps!: ['bundle exec cap $ENVIRONMENT deploy'],
        rollback_steps!: ['bundle exec cap $ENVIRONMENT deploy:rollback'],
        machine_env: { 'GLOBAL' => '1' },
        directory: nil,
        clear_working_directory?: true,
      )
      @commands.stubs(:deploy_spec).returns(@deploy_spec)

      StackCommands.stubs(git_version: Gem::Version.new('1.8.4.3'))
    end

    test "#fetch_commit calls git fetch if repository cache already exist" do
      @stack.git_path.stubs(:exist?).returns(true)
      @stack.git_path.stubs(:empty?).returns(false)

      command = @commands.fetch_commit(@deploy.until_commit)

      assert_equal %W(git fetch origin --quiet --tags #{@deploy.until_commit.sha}), command.args
    end

    test "#fetch_commit calls git fetch in git_path directory if repository cache already exist" do
      @stack.git_path.stubs(:exist?).returns(true)
      @stack.git_path.stubs(:empty?).returns(false)

      command = @commands.fetch_commit(@deploy.until_commit)

      assert_equal @stack.git_path.to_s, command.chdir
    end

    test "#fetch_commit calls git clone if repository cache do not exist" do
      @stack.git_path.stubs(:exist?).returns(false)

      command = @commands.fetch_commit(@deploy.until_commit)

      expected = %W(git clone --quiet --single-branch --recursive --branch master #{@stack.repo_git_url} #{@stack.git_path})
      assert_equal expected, command.args.map(&:to_s)
    end

    test "#fetch_commit calls git clone if repository cache is empty" do
      @stack.git_path.stubs(:exist?).returns(true)
      @stack.git_path.stubs(:empty?).returns(true)

      command = @commands.fetch_commit(@deploy.until_commit)

      expected = %W(git clone --quiet --single-branch --recursive --branch master #{@stack.repo_git_url} #{@stack.git_path})
      assert_equal expected, command.args
    end

    test "#fetch_commit calls git clone if repository cache corrupt" do
      @stack.git_path.stubs(:exist?).returns(true)
      @stack.git_path.stubs(:empty?).returns(false)
      StackCommands.any_instance.expects(:git_cmd_succeeds?)
        .with(@stack.git_path)
        .returns(false)

      command = @commands.fetch_commit(@deploy.until_commit)

      expected = %W(git clone --quiet --single-branch --recursive --branch master #{@stack.repo_git_url} #{@stack.git_path})
      assert_equal expected, command.args
    end

    test "#fetch_commit clears a corrupted git stash before cloning" do
      @stack.expects(:clear_git_cache!)
      @stack.git_path.stubs(:exist?).returns(true)
      @stack.git_path.stubs(:empty?).returns(false)
      StackCommands.any_instance.expects(:git_cmd_succeeds?)
        .with(@stack.git_path)
        .returns(false)

      command = @commands.fetch_commit(@deploy.until_commit)

      expected = %W(git clone --quiet --single-branch --recursive --branch master #{@stack.repo_git_url} #{@stack.git_path})
      assert_equal expected, command.args
    end

    test "#fetch_commit does not use --single-branch if git is outdated" do
      @stack.git_path.stubs(:exist?).returns(false)
      StackCommands.stubs(git_version: Gem::Version.new('1.7.2.30'))

      command = @commands.fetch_commit(@deploy.until_commit)

      expected = %W(git clone --quiet --recursive --branch master #{@stack.repo_git_url} #{@stack.git_path})
      assert_equal expected, command.args.map(&:to_s)
    end

    test "#fetch_commit calls git fetch in base_path directory if repository cache do not exist" do
      @stack.git_path.stubs(:exist?).returns(false)

      command = @commands.fetch_commit(@deploy.until_commit)

      assert_equal @stack.deploys_path.to_s, command.chdir
    end

    test "#fetch_commit merges Shipit.env in ENVIRONMENT" do
      Shipit.stubs(:env).returns("SPECIFIC_CONFIG" => 5)
      command = @commands.fetch_commit(@deploy.until_commit)
      assert_equal '5', command.env["SPECIFIC_CONFIG"]
    end

    test "#env uses the correct Github token for a stack" do
      Shipit.github(organization: 'shopify').stubs(:token).returns('aS3cr3Tt0kEn')
      command = @commands.fetch_commit(@deploy.until_commit)
      assert_equal 'aS3cr3Tt0kEn', command.env["GITHUB_TOKEN"]
    end

    test "#fetch calls git fetch if repository cache already exist" do
      @stack.git_path.stubs(:exist?).returns(true)
      @stack.git_path.stubs(:empty?).returns(false)

      command = @commands.fetch

      assert_equal %w(git fetch origin --quiet --tags master), command.args
    end

    test "#fetch calls git fetch in git_path directory if repository cache already exist" do
      @stack.git_path.stubs(:exist?).returns(true)
      @stack.git_path.stubs(:empty?).returns(false)

      command = @commands.fetch

      assert_equal @stack.git_path.to_s, command.chdir
    end

    test "#fetch calls git clone if repository cache do not exist" do
      @stack.git_path.stubs(:exist?).returns(false)

      command = @commands.fetch

      expected = %W(git clone --quiet --single-branch --recursive --branch master #{@stack.repo_git_url} #{@stack.git_path})
      assert_equal expected, command.args.map(&:to_s)
    end

    test "#fetch calls git clone if repository cache is empty" do
      @stack.git_path.stubs(:exist?).returns(true)
      @stack.git_path.stubs(:empty?).returns(true)

      command = @commands.fetch

      expected = %W(git clone --quiet --single-branch --recursive --branch master #{@stack.repo_git_url} #{@stack.git_path})
      assert_equal expected, command.args
    end

    test "#fetch calls git clone if repository cache corrupt" do
      @stack.git_path.stubs(:exist?).returns(true)
      @stack.git_path.stubs(:empty?).returns(false)
      StackCommands.any_instance.expects(:git_cmd_succeeds?)
        .with(@stack.git_path)
        .returns(false)

      command = @commands.fetch

      expected = %W(git clone --quiet --single-branch --recursive --branch master #{@stack.repo_git_url} #{@stack.git_path})
      assert_equal expected, command.args
    end

    test "#fetch clears a corrupted git stash before cloning" do
      @stack.expects(:clear_git_cache!)
      @stack.git_path.stubs(:exist?).returns(true)
      @stack.git_path.stubs(:empty?).returns(false)
      StackCommands.any_instance.expects(:git_cmd_succeeds?)
        .with(@stack.git_path)
        .returns(false)

      command = @commands.fetch

      expected = %W(git clone --quiet --single-branch --recursive --branch master #{@stack.repo_git_url} #{@stack.git_path})
      assert_equal expected, command.args
    end

    test "#fetch does not use --single-branch if git is outdated" do
      @stack.git_path.stubs(:exist?).returns(false)
      StackCommands.stubs(git_version: Gem::Version.new('1.7.2.30'))

      command = @commands.fetch

      expected = %W(git clone --quiet --recursive --branch master #{@stack.repo_git_url} #{@stack.git_path})
      assert_equal expected, command.args.map(&:to_s)
    end

    test "#fetch calls git fetch in base_path directory if repository cache do not exist" do
      @stack.git_path.stubs(:exist?).returns(false)

      command = @commands.fetch

      assert_equal @stack.deploys_path.to_s, command.chdir
    end

    test "#fetch merges Shipit.env in ENVIRONMENT" do
      Shipit.stubs(:env).returns("SPECIFIC_CONFIG" => 5)
      command = @commands.fetch
      assert_equal '5', command.env["SPECIFIC_CONFIG"]
    end

    test "#clone clones the repository cache into the working directory" do
      commands = @commands.clone
      assert_equal 2, commands.size
      clone_args = [
        'git', 'clone', '--quiet',
        '--local', '--origin', 'cache',
        @stack.git_path.to_s, @deploy.working_directory,
      ]
      assert_equal clone_args, commands.first.args
      assert_equal ['git', 'remote', 'add', 'origin', @stack.repo_git_url.to_s], commands.second.args
    end

    test "#clone clones the repository cache from the deploys_path" do
      commands = @commands.clone
      assert_equal @stack.deploys_path.to_s, commands.first.chdir
    end

    test "#checkout checks out the deployed commit" do
      command = @commands.checkout(@deploy.until_commit)
      checkout_args = [
        'git', '-c', 'advice.detachedHead=false', 'checkout', '--quiet',
        @deploy.until_commit.sha,
      ]
      assert_equal checkout_args, command.args
    end

    test "#checkout checks out the deployed commit from the working directory" do
      command = @commands.checkout(@deploy.until_commit)
      assert_equal @deploy.working_directory, command.chdir
    end

    test "#perform calls cap $environment deploy" do
      commands = @commands.perform
      assert_equal 1, commands.length
      command = commands.first
      assert_equal ['bundle exec cap $ENVIRONMENT deploy'], command.args
    end

    test "#perform calls cap $environment deploy:rollback for a rollback of a capistrano stack" do
      @rollback = @deploy.build_rollback
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
      assert_equal @deploy.working_directory, command.chdir
    end

    test "the working_directory can be overriten in the spec" do
      @deploy_spec.stubs(:directory).returns('my_directory')
      commands = @commands.perform
      assert_equal 1, commands.length
      command = commands.first
      assert_equal File.join(@deploy.working_directory, 'my_directory'), command.chdir
    end

    test "#perform calls cap $environment deploy with the SHA in the environment" do
      commands = @commands.perform
      assert_equal 1, commands.length
      command = commands.first
      assert_equal @deploy.until_commit.sha, command.env['SHA']
    end

    test "#perform calls cap $environment deploy with the SHIPIT_LINK in the environment" do
      commands = @commands.perform
      assert_equal 1, commands.length
      command = commands.first
      url = "http://shipit.com/shopify/shipit-engine/production/deploys/#{@deploy.id}"
      assert_equal url, command.env['SHIPIT_LINK']
    end

    test "#perform calls cap $environment deploy with the LAST_DEPLOYED_SHA in the environment" do
      commands = @commands.perform
      assert_equal 1, commands.length
      command = commands.first
      assert_equal @deploy.stack.last_deployed_commit.sha, command.env['LAST_DEPLOYED_SHA']
    end

    test "#perform calls cap $environment deploy with the TASK_ID in the environment" do
      commands = @commands.perform
      assert_equal 1, commands.length
      command = commands.first
      assert_equal @deploy.id.to_s, command.env['TASK_ID']
    end

    test "#perform transliterates the user name" do
      @deploy.user = User.new(login: 'Sirupsen', name: "Simon Hørup Eskildsen")
      commands = @commands.perform
      assert_equal 1, commands.length
      command = commands.first
      assert_equal "Sirupsen (Simon Horup Eskildsen) via Shipit", command.env['SHIPIT_USER']
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
      assert_equal '5', command.env["SPECIFIC_CONFIG"]
    end

    test "#install_dependencies merges machine_env in ENVIRONMENT" do
      command = @commands.install_dependencies.first
      assert_equal '1', command.env['GLOBAL']
    end

    test "the deploy's `env` is merged in ENVIRONMENT" do
      @deploy.env = { 'FOO' => 'BAR' }
      command = @commands.install_dependencies.first
      assert_equal 'BAR', command.env['FOO']
    end

    test "IGNORED_SAFETIES is exposed" do
      assert_equal '0', @commands.env['IGNORED_SAFETIES']
      @deploy.ignored_safeties = true
      assert_equal '1', @commands.env['IGNORED_SAFETIES']
    end

    test "GIT_COMMITTER_NAME and GIT_COMMITTER_EMAIL are exposed" do
      assert_equal 'shipit@shipit.com', @commands.env['GIT_COMMITTER_EMAIL']
      assert_equal 'Shipit', @commands.env['GIT_COMMITTER_NAME']

      walrus = shipit_users(:walrus)
      @deploy.update!(user: walrus)

      assert_equal walrus.email, @commands.env['GIT_COMMITTER_EMAIL']
      assert_equal walrus.name, @commands.env['GIT_COMMITTER_NAME']
    end

    test "GitHub repo details are exposed" do
      assert_equal 'shopify', @commands.env['GITHUB_REPO_OWNER']
      assert_equal 'shipit-engine', @commands.env['GITHUB_REPO_NAME']
    end

    test "Stack DEPLOY_URL is exposed" do
      assert_equal "https://shipit.shopify.com", @commands.env['DEPLOY_URL']
    end

    test "#clear_working_directory rm -rf the working directory" do
      FileUtils.expects(:rm_rf).with(@deploy.working_directory)
      @commands.clear_working_directory
    end

    test "#clear_working_directory is a noop if the deploy spec disabled cleanup" do
      @deploy_spec.expects(:clear_working_directory?).returns(false)
      FileUtils.expects(:rm_rf).never
      @commands.clear_working_directory
    end
  end
end
