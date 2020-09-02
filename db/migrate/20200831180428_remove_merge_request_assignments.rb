# frozen_string_literal: true
class RemoveMergeRequestAssignments < ActiveRecord::Migration[6.0]
  def up
    drop_table :merge_request_assignments
  end

  def down
    create_table :merge_request_assignments do |t|
      t.references :pull_request
      t.references :user
    end
  end
end
