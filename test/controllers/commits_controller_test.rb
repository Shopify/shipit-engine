require 'test_helper'

class CommitsControllerTest < ActionController::TestCase
  test "#show renders the commit partial" do
    commit = commits(:first)
    get :show, id: commit.id, stack_id: commit.stack.to_param
    assert_select "#commit-1"
  end
end
