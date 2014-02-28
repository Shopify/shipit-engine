require 'test_helper'

class StacksControllerTest < ActionController::TestCase
  setup do
    @stack = stacks(:shipit)
  end

  test "#create creates a Stack, queues a job to setup webhooks and redirects to it" do
    params = {}
    params[:stack] = {
      :repo_name   => "rails",
      :repo_owner  => "rails",
      :environment => "staging",
      :branch      => "staging"
    }

    assert_difference "Stack.count" do
      post :create, params
    end

    assert_redirected_to stack_path(Stack.last)
  end

  test "#destroy behaves correctly" do
    delete :destroy, :id => @stack.to_param
    assert_redirected_to stacks_path
  end
end
