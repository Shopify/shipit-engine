require 'test_helper'

class StacksControllerTest < ActionController::TestCase
  setup do
    @stack = stacks(:shipit)
  end

  test "#create behaves correctly" do
    params = {}
    params[:stack] = {
      :repo_name   => "rails",
      :repo_owner  => "rails",
      :environment => "staging",
      :branch      => "staging"
    }
    post :create, params
    assert_redirected_to stack_path(Stack.last)
  end

  test "#destroy behaves correctly" do
    delete :destroy, :id => @stack.id
    assert_redirected_to stacks_path
  end
end
