class PredictiveBranchCommits < ActiveRecord::Migration[6.0]

  def change
    add_reference :predictive_branches, :until_commit, foreign_key: {to_table: :commits}, null: true, type: :int
  end

end

