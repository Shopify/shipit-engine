require 'test_helper'

class CommandTest < ActiveSupport::TestCase
  test 'lib/snippets is added to the PATH when command is run' do
    out = Command.new('which extract-gem-version', chdir: '/tmp').run
    script_path = Rails.root.join('lib', 'snippets', 'extract-gem-version').to_s
    assert_equal "#{script_path}\n", out
  end

  test "#interpolate_environment_variables replace environment variables by their value" do
    command = Command.new('cap $ENVIRONMENT deploy', env: {'ENVIRONMENT' => 'production'}, chdir: '.')
    assert_equal [%(cap production deploy)], command.interpolated_arguments
  end

  test "#interpolate_environment_variables coerce nil to empty string" do
    command = Command.new('cap $FOO deploy', env: {'ENVIRONMENT' => 'production'}, chdir: '.')
    assert_equal [%(cap '' deploy)], command.interpolated_arguments
  end

  test "#interpolate_environment_variables fallback to ENV" do
    command = Command.new('cap $LANG deploy', env: {'ENVIRONMENT' => 'production'}, chdir: '.')
    assert_equal [%(cap #{ENV['LANG']} deploy)], command.interpolated_arguments
  end
end
