# frozen_string_literal: true
require 'test_helper'

module Shipit
  module Api
    class OutputsControllerTest < ApiControllerTestCase
      setup do
        @stack = shipit_stacks(:shipit)
        authenticate!
      end

      test "#show returns the task output as plain text" do
        task = @stack.tasks.last
        task.write("dummy output")

        get :show, params: { stack_id: @stack.to_param, task_id: task.id }
        assert_response :ok
        assert_equal 'text/plain', response.media_type
        assert_equal task.chunk_output, response.body
      end
    end
  end
end
