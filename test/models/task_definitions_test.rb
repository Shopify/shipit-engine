require 'test_helper'

module Shipit
  class TaskDefinitionsTest < ActiveSupport::TestCase
    setup do
      @definition = TaskDefinition.new(
        'restart',
        'action' => 'Restart application',
        'description' => 'Restart app and job servers',
        'steps' => ['touch tmp/restart'],
        'allow_concurrency' => true,
      )
    end

    test ".load returns nil if payload is nil or blank" do
      assert_nil TaskDefinition.load('')
      assert_nil TaskDefinition.load(nil)
    end

    test ".dump returns nil if given nil" do
      assert_nil TaskDefinition.dump(nil)
    end

    test "serialization works" do
      as_json = {
        id: 'restart',
        action: 'Restart application',
        description: 'Restart app and job servers',
        steps: ['touch tmp/restart'],
        checklist: [],
        allow_concurrency: true,
      }
      assert_equal as_json, TaskDefinition.load(TaskDefinition.dump(@definition)).as_json
    end
  end
end
