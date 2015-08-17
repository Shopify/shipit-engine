require 'test_helper'

class CommandTest < ActiveSupport::TestCase
  test 'lib/snippets is added to the PATH when command is run' do
    out = Command.new('which extract-gem-version', chdir: '/tmp').run
    script_path = Shipit::Engine.root.join('lib', 'snippets', 'extract-gem-version').to_s
    assert_equal "#{script_path}\r\n", out
  end

  test "#interpolate_environment_variables replace environment variables by their value" do
    command = Command.new('cap $ENVIRONMENT deploy', env: {'ENVIRONMENT' => 'production'}, chdir: '.')
    assert_equal [%(cap production deploy)], command.interpolated_arguments
  end

  test "#interpolate_environment_variables coerce nil to empty string" do
    command = Command.new('cap $FOO deploy', env: {'ENVIRONMENT' => 'production'}, chdir: '.')
    assert_equal [%(cap '' deploy)], command.interpolated_arguments
  end

  test '#interpolate_environment_variables escape the variable contents' do
    malicious_string = '$(echo pwnd)'
    command = Command.new('echo $FOO', env: {'FOO' => malicious_string}, chdir: '.')
    assert_equal malicious_string, command.run.chomp
  end

  test "#interpolate_environment_variables fallback to ENV" do
    command = Command.new('cap $LANG deploy', env: {'ENVIRONMENT' => 'production'}, chdir: '.')
    assert_equal [%(cap #{ENV['LANG']} deploy)], command.interpolated_arguments
  end

  test "#timeout is 5 minutes by default" do
    command = Command.new('cap $LANG deploy', env: {'ENVIRONMENT' => 'production'}, chdir: '.')
    assert_equal 5.minutes.to_i, command.timeout
  end

  test "#timeout returns `default_timeout` if present" do
    command = Command.new('cap $LANG deploy', default_timeout: 5, env: {}, chdir: '.')
    assert_equal 5, command.timeout
  end

  test "#timeout returnsthe command option timeout over the `default_timeout` if present" do
    command = Command.new({'cap $LANG deploy' => {'timeout' => 10}}, default_timeout: 5, env: {}, chdir: '.')
    assert_equal 10, command.timeout
  end
end
