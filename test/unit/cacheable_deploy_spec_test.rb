# frozen_string_literal: true

require 'test_helper'

module Shipit
  class CacheableDeploySpecTest < ActiveSupport::TestCase
    setup do
      @stack = shipit_stacks(:shipit)
      @commands = StackCommands.new(@stack)
      @commit = @stack.commits.last
      @old_spec = DeploySpec.new('deploy' => { 'override' => ['echo old'] })
      @new_spec = DeploySpec.new('deploy' => { 'override' => ['echo new'] })
      @events = []
      @subscriber = ActiveSupport::Notifications.subscribe('checkout_less_deploy_spec.shipit') do |*, payload|
        @events << payload
      end
    end

    teardown do
      ActiveSupport::Notifications.unsubscribe(@subscriber)
      Shipit.checkout_less_deploy_spec = :disabled
    end

    test "the flag rejects unknown modes" do
      assert_raises(ArgumentError) { Shipit.checkout_less_deploy_spec = :bogus }
      assert_equal :disabled, Shipit.checkout_less_deploy_spec
    end

    test "disabled mode uses the checkout path with recursive: false" do
      Shipit.checkout_less_deploy_spec = :disabled
      @commands.expects(:with_temporary_working_directory)
               .with(commit: @commit, recursive: false).returns([@old_spec, '/tmp/old'])
      @commands.expects(:git_object_cacheable_deploy_spec).never

      assert_equal @old_spec, @commands.cacheable_deploy_spec(commit: @commit)
    end

    test "a nil commit always uses the checkout path" do
      Shipit.checkout_less_deploy_spec = :enabled
      @commands.expects(:checkout_cacheable_deploy_spec).with(nil).returns([@old_spec, '/tmp/old'])
      @commands.expects(:git_object_cacheable_deploy_spec).never

      assert_equal @old_spec, @commands.cacheable_deploy_spec(commit: nil)
    end

    test "enabled mode serves the git object path and reports a hit" do
      Shipit.checkout_less_deploy_spec = :enabled
      @commands.expects(:git_object_cacheable_deploy_spec).with(@commit).returns([@new_spec, '/tmp/new'])
      @commands.expects(:checkout_cacheable_deploy_spec).never

      assert_equal @new_spec, @commands.cacheable_deploy_spec(commit: @commit)
      assert_equal([:hit], @events.map { |e| e[:event] })
    end

    test "enabled mode falls back on FallbackRequired" do
      Shipit.checkout_less_deploy_spec = :enabled
      error = DeploySpec::GitObjectFileSystem::FallbackRequired.new(:symlink, 'some/path')
      @commands.expects(:git_object_cacheable_deploy_spec).raises(error)
      @commands.expects(:checkout_cacheable_deploy_spec).with(@commit).returns([@old_spec, '/tmp/old'])

      assert_equal @old_spec, @commands.cacheable_deploy_spec(commit: @commit)
      assert_equal([{ event: :fallback, reason: :symlink }],
                   @events.map { |e| e.slice(:event, :reason) })
    end

    test "enabled mode falls back on git command failure" do
      Shipit.checkout_less_deploy_spec = :enabled
      @commands.expects(:git_object_cacheable_deploy_spec).raises(Command::Failed.new('boom', 128))
      @commands.expects(:checkout_cacheable_deploy_spec).with(@commit).returns([@old_spec, '/tmp/old'])

      assert_equal @old_spec, @commands.cacheable_deploy_spec(commit: @commit)
      assert_equal :git_error, @events.first[:reason]
    end

    test "enabled mode falls back on unexpected errors" do
      Shipit.checkout_less_deploy_spec = :enabled
      @commands.expects(:git_object_cacheable_deploy_spec).raises(RuntimeError.new('surprise'))
      @commands.expects(:checkout_cacheable_deploy_spec).with(@commit).returns([@old_spec, '/tmp/old'])

      assert_equal @old_spec, @commands.cacheable_deploy_spec(commit: @commit)
      assert_equal :unexpected_error, @events.first[:reason]
    end

    test "shadow mode returns the checkout result and reports a hit on match" do
      Shipit.checkout_less_deploy_spec = :shadow
      same = DeploySpec.new(@old_spec.config)
      @commands.expects(:checkout_cacheable_deploy_spec).with(@commit).returns([@old_spec, '/tmp/old'])
      @commands.expects(:git_object_cacheable_deploy_spec).with(@commit).returns([same, '/tmp/new'])

      assert_equal @old_spec, @commands.cacheable_deploy_spec(commit: @commit)
      assert_equal([:hit], @events.map { |e| e[:event] })
    end

    test "shadow mode returns the checkout result and reports a mismatch on divergence" do
      Shipit.checkout_less_deploy_spec = :shadow
      @commands.expects(:checkout_cacheable_deploy_spec).with(@commit).returns([@old_spec, '/tmp/old'])
      @commands.expects(:git_object_cacheable_deploy_spec).with(@commit).returns([@new_spec, '/tmp/new'])

      assert_equal @old_spec, @commands.cacheable_deploy_spec(commit: @commit)
      assert_equal([:shadow_mismatch], @events.map { |e| e[:event] })
      assert_includes @events.first[:detail], 'deploy'
    end

    test "shadow mode never propagates new-path exceptions" do
      Shipit.checkout_less_deploy_spec = :shadow
      @commands.expects(:checkout_cacheable_deploy_spec).with(@commit).returns([@old_spec, '/tmp/old'])
      @commands.expects(:git_object_cacheable_deploy_spec).raises(RuntimeError.new('boom'))

      assert_equal @old_spec, @commands.cacheable_deploy_spec(commit: @commit)
      assert_equal :shadow_error, @events.first[:reason]
    end

    test "shadow mode propagates old-path exceptions unchanged" do
      Shipit.checkout_less_deploy_spec = :shadow
      @commands.expects(:checkout_cacheable_deploy_spec).raises(RuntimeError.new('old path broke'))

      assert_raises(RuntimeError) { @commands.cacheable_deploy_spec(commit: @commit) }
    end

    test "build_cacheable_deploy_spec delegates to the wrapper with a nil commit" do
      @commands.expects(:cacheable_deploy_spec).with(commit: nil).returns(@old_spec)
      assert_equal @old_spec, @commands.build_cacheable_deploy_spec
    end
  end
end
