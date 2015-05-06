require 'test_helper'

class StatusControllerTest < ActionController::TestCase
  test ":version returns Shipster.revision" do
    Shipster.expects(:revision).returns('foo')
    get :version
    assert_response :success
    assert_equal 'foo', response.body
  end
end
