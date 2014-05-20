require 'test_helper'

class CommandTest < ActiveSupport::TestCase
  test 'lib/snippets is added to the PATH when command is run' do
    out = Command.new('which extract-gem-version', chdir: '/tmp').run
    script_path = Rails.root.join('lib', 'snippets', 'extract-gem-version').to_s
    assert_equal "#{script_path}\n", out
  end
end
