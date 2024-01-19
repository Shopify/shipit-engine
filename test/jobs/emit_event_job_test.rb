# frozen_string_literal: true

require 'test_helper'

module Shipit
  class EmitEventJobTest < ActiveSupport::TestCase
    setup do
      @stack = shipit_stacks(:shipit)
      @job = EmitEventJob.new
    end

    test "#perform schedule deliveries" do
      assert_enqueued_jobs(2, only: DeliverHookJob) do
        @job.perform(event: :deploy, stack_id: @stack.id, payload: { foo: 42 }.to_json)
      end
    end
  end
end
