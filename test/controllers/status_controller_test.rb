# frozen_string_literal: true
require 'test_helper'

module Shipit
  class StatusControllerTest < ActionController::TestCase
    test ":version returns Shipit.revision" do
      Shipit.expects(:revision).returns('foo')
      get :version
      assert_response :success
      assert_equal 'foo', response.body
    end
  end
end
