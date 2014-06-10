require 'test_helper'

class CommandsTest < ActiveSupport::TestCase
  def setup
    @commands = Commands.new
  end

  test 'SHIPIT gets added to the environment variables' do
    assert_equal '1', @commands.env['SHIPIT']
  end
end
