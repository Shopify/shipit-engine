class RenamePullRequestAssignmentsToMergeRequestAssignments < ActiveRecord::Migration[6.0]
  def change
    create_table :merge_request_assignments do |t|
      t.references :merge_request
      t.references :user
    end

    ActiveRecord::Base.connection.execute(
      <<~EOS
        INSERT INTO merge_request_assignments SELECT * FROM pull_request_assignments;
      EOS
    )

    drop_table :pull_request_assignments
    create_table :pull_request_assignments do |t|
      t.references :pull_request
      t.references :user
    end
  end
end
