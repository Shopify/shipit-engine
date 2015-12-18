require 'test_helper'

class MissingStatusTest < ActiveSupport::TestCase
  setup do
    @real_status = statuses(:first_pending)
    @status = MissingStatus.new(@real_status, %w(ci/very-important style/very-important-too))
  end

  test "#state is 'missing'" do
    assert_equal 'missing', @status.state
  end

  test "#description explains the situation" do
    message = 'ci/very-important and style/very-important-too are required for deploy but were not sent'
    assert_equal message, @status.description
  end

  test "#success? is false" do
    refute_predicate @status, :success?
  end
end
