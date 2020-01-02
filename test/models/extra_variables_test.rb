require 'test_helper'

module Shipit
  class ExtraVariablesTest < ActiveSupport::TestCase
    def setup
      @stack = shipit_stacks(:shipit)
    end

    test 'invalid without key' do
      extra_var = ExtraVariable.new(stack: @stack, value: 'VALUE')
      refute extra_var.valid?
      assert_not_nil extra_var.errors[:key]
    end

    test 'invalid without value' do
      extra_var = ExtraVariable.new(stack: @stack, key: 'KEY')
      refute extra_var.valid?
      assert_not_nil extra_var.errors[:value]
    end

    test 'invalid if key already defined' do
      extra_var = ExtraVariable.new(shipit_extra_variables(:target).attributes)
      refute extra_var.valid?
      assert_not_nil extra_var.errors[:key]
    end
  end
end
