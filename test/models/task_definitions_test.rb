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
        'variables' => [
          {'name' => 'FOO', 'title' => 'Set to 0 to foo', 'default' => '1'},
          {'name' => 'BAR', 'title' => 'Set to 1 to bar', 'default' => '0'},
        ],
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
        variables: [
          {'name' => 'FOO', 'title' => 'Set to 0 to foo', 'default' => '1', 'select' => nil},
          {'name' => 'BAR', 'title' => 'Set to 1 to bar', 'default' => '0', 'select' => nil},
        ],
      }
      assert_equal as_json, TaskDefinition.load(TaskDefinition.dump(@definition)).as_json
    end
  end
end
