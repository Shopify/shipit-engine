require 'test_helper'

class SecretsControllerTest < ActionController::TestCase
  setup do
    @stack = stacks(:shipit)
    session[:user_id] = users(:walrus).id
  end

  test "#create merge the new secrets to the store" do
    post :create, stack_id: @stack.to_param, secret: {key: 'SECRET_KEY', secret_value: 'S3CR3T1'}
    assert_redirected_to settings_stack_path(@stack)
    assert_equal 'S3CR3T1', @stack.reload.secrets['SECRET_KEY']
  end

  test "#destroy remove the secret from the store" do
    @stack.update!(secrets: {'SECRET_KEY' => 'S3CR3T1'})

    delete :destroy, stack_id: @stack.to_param, id: 'SECRET_KEY'
    assert_redirected_to settings_stack_path(@stack)
    refute @stack.reload.secrets.key?('SECRET_KEY')
  end

end
