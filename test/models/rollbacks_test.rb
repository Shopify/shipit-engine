require 'test_helper'

class RollbackTest < ActiveSupport::TestCase
  setup do
    @rollback = Rollback.new
  end

  test "#rollback? returns true" do
    assert @rollback.rollback?
  end
end
