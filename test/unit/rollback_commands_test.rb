# frozen_string_literal: true

require 'test_helper'

module Shipit
  class RollbackCommandsTest < ActiveSupport::TestCase
    def setup
      @stack = shipit_stacks(:shipit)
      @rollback = shipit_rollbacks(:shipit_rollback)
      @commands = RollbackCommands.new(@rollback)
      @deploy_spec = stub(
        dependencies_steps!: ['bundle install --some-args'],
        deploy_steps!: ['bundle exec cap $ENVIRONMENT deploy'],
        rollback_steps!: ['bundle exec cap $ENVIRONMENT deploy:rollback'],
        machine_env: { 'GLOBAL' => '1' },
        directory: nil,
        clear_working_directory?: true
      )
      @commands.stubs(:deploy_spec).returns(@deploy_spec)

      StackCommands.stubs(git_version: Gem::Version.new('1.8.4.3'))
    end

    test "#perform calls cap $environment deploy" do
      commands = @commands.perform
      assert_equal 1, commands.length
      command = commands.first
      assert_equal ['bundle exec cap $ENVIRONMENT deploy:rollback'], command.args
    end

    test "#perform sets ROLLBACK=1" do
      commands = @commands.perform
      command = commands.first
      assert_equal '1', command.env['ROLLBACK']
    end

    test "failure_step returns nil if there's no rollback_post step" do
      @deploy_spec.stubs(:rollback_post).returns(nil)
      assert_nil @commands.failure_step
    end

    test "failure_step returns a Command if there's a rollback_post with config to run on_error" do
      @deploy_spec.stubs(:rollback_post).returns('echo "hello"' => { 'on_error' => true })
      command = @commands.failure_step
      assert_instance_of Command, command
      assert_equal ['echo "hello"'], command.args
    end

    test "failure_step returns nil if there's a rollback_post without config to run on_error" do
      @deploy_spec.stubs(:rollback_post).returns('echo "hello"')
      assert_nil @commands.failure_step
    end
  end
end
