# frozen_string_literal: true

require 'test_helper'

module Shipit
  class MissingStatusTest < ActiveSupport::TestCase
    setup do
      @commit = @commit = shipit_commits(:second)
      @status = Status::Missing.new(@commit, 'ci/very-important')
    end

    test "#state is 'pending'" do
      assert_equal 'pending', @status.state
    end

    test "#description explains the situation" do
      message = 'ci/very-important is required for deploy but was not sent yet.'
      assert_equal message, @status.description
    end

    test "#success? is false" do
      refute_predicate @status, :success?
    end
  end
end
