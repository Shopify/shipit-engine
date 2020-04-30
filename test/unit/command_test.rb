# frozen_string_literal: true
require 'test_helper'

module Shipit
  class CommandTest < ActiveSupport::TestCase
    test 'lib/snippets is added to the PATH when command is run' do
      out = Command.new('which extract-gem-version', chdir: '/tmp').run
      script_path = Shipit::Engine.root.join('lib', 'snippets', 'extract-gem-version').to_s
      assert_equal "#{script_path}\r\n", out
    end

    test "#interpolate_environment_variables replace environment variables by their value" do
      command = Command.new('cap $ENVIRONMENT deploy', env: { 'ENVIRONMENT' => 'production' }, chdir: '.')
      assert_equal [%(cap production deploy)], command.interpolated_arguments
    end

    test "#interpolate_environment_variables coerce nil to empty string" do
      command = Command.new('cap $FOO deploy', env: { 'ENVIRONMENT' => 'production' }, chdir: '.')
      assert_equal [%(cap '' deploy)], command.interpolated_arguments
    end

    test '#interpolate_environment_variables escape the variable contents' do
      malicious_string = '$(echo pwnd)'
      command = Command.new('echo $FOO', env: { 'FOO' => malicious_string }, chdir: '.')
      assert_equal malicious_string, command.run.chomp
    end

    test "#interpolate_environment_variables fallback to ENV" do
      previous = ENV['SHIPIT_TEST']
      ENV['SHIPIT_TEST'] = 'quux'
      command = Command.new('cap $SHIPIT_TEST deploy', env: { 'ENVIRONMENT' => 'production' }, chdir: '.')
      assert_equal([%(cap quux deploy)], command.interpolated_arguments)
    ensure
      ENV['SHIPIT_TEST'] = previous
    end

    test "#timeout is 5 minutes by default" do
      command = Command.new('cap $LANG deploy', env: { 'ENVIRONMENT' => 'production' }, chdir: '.')
      assert_equal 5.minutes.to_i, command.timeout
    end

    test "#timeout returns `default_timeout` if present" do
      command = Command.new('cap $LANG deploy', default_timeout: 5, env: {}, chdir: '.')
      assert_equal 5, command.timeout
    end

    test "#timeout returns the command option timeout over the `default_timeout` if present" do
      command = Command.new({ 'cap $LANG deploy' => { 'timeout' => 10 } }, default_timeout: 5, env: {}, chdir: '.')
      assert_equal 10, command.timeout
    end

    test "the process is properly terminated if it times out" do
      # Minitest being run in an at_exit callback, signal handling etc is unreliable
      assert system(
        Engine.root.join('test/dummy/bin/rails').to_s,
        'runner',
        Engine.root.join('test/test_command_integration.rb').to_s,
      )
    end

    test "command not found" do
      error = assert_raises Command::NotFound do
        Command.new('does-not-exist foo bar', env: {}, chdir: '.').run
      end
      assert_equal 'does-not-exist: command not found', error.message
    end

    test "permission denied" do
      error = assert_raises Command::Denied do
        Command.new('/etc/passwd foo bar', env: {}, chdir: '.').run
      end
      assert_equal '/etc/passwd: Permission denied', error.message
    end

    test 'sets code and message correctly on success' do
      command = Command.new('true', chdir: '.')
      assert_nil command.code
      command.run
      refute_predicate command, :running?
      assert_predicate command.code, :zero?
      assert_equal 'terminated successfully', command.termination_status
    end

    test 'sets code and message correctly on error' do
      command = Command.new('false', chdir: '.')
      assert_nil command.code
      command.run
      refute_predicate command, :running?
      assert_predicate command.code, :nonzero?
      assert_equal 'terminated with exit status 1', command.termination_status
    end

    test 'handles externally signalled commands correctly' do
      command = Command.new('sleep 10', chdir: '.')
      t = command_signaller_thread(command)
      command.run
      assert t.join, "subprocess wasn't signalled"
      assert_predicate command, :signaled?
      refute_predicate command, :running?
      assert_nil command.code
      assert_equal 'terminated with KILL signal', command.termination_status
    end

    test 'reports timedout command correctly' do
      command = Command.new('sleep 10', chdir: '.', default_timeout: 0.5)
      assert_raises(Command::TimedOut) { command.run }
      assert_predicate command, :signaled?
      refute_predicate command, :running?
      assert_nil command.code
      assert_equal 'timed out and terminated with INT signal', command.termination_status
    end

    private

    def command_signaller_thread(command, signal: 'KILL')
      Thread.new do
        signalled = false
        20.times do
          if command.running?
            Process.kill(signal, command.pid)
            signalled = true
            break
          end
          sleep 0.1
        end
        signalled
      end
    end
  end
end
