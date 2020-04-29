# frozen_string_literal: true
require 'test_helper'

module Shipit
  class CommandsTest < ActiveSupport::TestCase
    def setup
      @commands = Commands.new
    end

    test 'SHIPIT gets added to the environment variables' do
      assert_equal '1', @commands.env['SHIPIT']
    end

    test 'parse_git_version handles rc releases' do
      assert_equal Gem::Version.new('2.8.0'), Commands.parse_git_version('git version 2.8.0.rc3')
    end
  end
end
