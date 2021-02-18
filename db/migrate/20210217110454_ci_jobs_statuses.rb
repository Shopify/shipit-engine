class CiJobsStatuses < ActiveRecord::Migration[6.0]

  def change

    create_table :ci_jobs_statuses, if_not_exists: true do |t|
      t.references :predictive_build,               foreign_key: true, type: :bigint
      t.references :predictive_branch,               foreign_key: true, type: :bigint
      t.string    "name",     limit: 100,       null: false
      t.string    "status",   limit: 50,        default: "running",   null: false
      t.text      "link",     limit: 16777215,  null: false
      t.timestamps
    end

  end

end

