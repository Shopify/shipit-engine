require 'test_helper'

class RollbackTest < ActiveSupport::TestCase
  setup do
    @rollback = Rollback.new
  end

  test "#rollback? returns true" do
    assert @rollback.rollback?
  end

  test "#rollbackable? returns false" do
    refute @rollback.rollbackable?
  end

  test "#supports_rollback? returns false" do
    refute @rollback.supports_rollback?
  end
end
