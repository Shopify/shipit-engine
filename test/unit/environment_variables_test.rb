# frozen_string_literal: true

require 'test_helper'

module Shipit
  class EnvironmentVariablesTest < ActiveSupport::TestCase
    def setup
      variable_defs = [
        { "name" => "FOO", "title" => "Set to 0 to foo", "default" => 1 },
        { "name" => "BAR", "title" => "Set to 1 to bar", "default" => 0 }
      ]
      @variable_definitions = variable_defs.map(&VariableDefinition.method(:new))
    end
    test 'empty env returns empty hash' do
      empty = {}
      assert_equal empty, EnvironmentVariables.with(nil).permit(@variable_definitions)
      assert_equal empty, EnvironmentVariables.with({}).permit(@variable_definitions)
    end

    test 'correctly sanitizes env variables' do
      env = { 'FOO' => 1, 'BAR' => 1 }
      assert_equal env, EnvironmentVariables.with(env).permit(@variable_definitions)
    end

    test 'empty permit raises not permitted error' do
      assert_raises(EnvironmentVariables::NotPermitted) do
        EnvironmentVariables.with('FOO' => 1).permit({})
      end
    end

    test 'throws an exception when a variable is not whitelisted' do
      env = { 'UNSAFE_VARIABLE' => 1 }
      assert_raises(EnvironmentVariables::NotPermitted) do
        EnvironmentVariables.with(env).permit(@variable_definitions)
      end
    end
  end
end
