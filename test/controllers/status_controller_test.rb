require 'test_helper'

class StatusControllerTest < ActionController::TestCase

  test ":version returns Shipit.revision" do
    Shipit.expects(:revision).returns('foo')
    get :version
    assert_response :success
    assert_equal 'foo', response.body
  end

end
