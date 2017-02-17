require 'test_helper'

module Shipit
  module Api
    class CcmenuControllerTest < ActionController::TestCase
      setup do
        authenticate!
        @stack = shipit_stacks(:shipit)
      end

      test "a request with insufficient permissions will render a 403" do
        @client.update!(permissions: [])
        get :show, params: {stack_id: @stack.to_param}
        assert_response :forbidden
        assert_json 'message', 'This operation requires the `read:stack` permission'
      end

      test "#show renders the stack" do
        get :show, params: {stack_id: @stack.to_param}
        assert_response :ok
        assert_payload 'name', @stack.to_param
      end

      test "xml contains required attributes" do
        get :show, params: {stack_id: @stack.to_param}
        project = get_project_from_xml(response.body)
        %w(name activity lastBuildStatus lastBuildLabel lastBuildTime webUrl).each do |attribute|
          assert_includes project, attribute, "Response missing required attribute: #{attribute}"
        end
      end

      test "locked stacks show as failed" do
        @stack.lock('test', @user)
        get :show, params: {stack_id: @stack.to_param}
        assert_payload 'lastBuildStatus', 'Failure'
      end

      private

      def get_project_from_xml(xml)
        Hash.from_xml(xml)['Projects']['Project']
      end

      def assert_payload(k, v)
        @project ||= get_project_from_xml(response.body)
        assert_equal v, @project[k]
      end
    end
  end
end
