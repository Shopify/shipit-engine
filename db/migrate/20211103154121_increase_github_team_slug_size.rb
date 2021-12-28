class IncreaseGithubTeamSlugSize < ActiveRecord::Migration[6.1]
  def change
    change_column :teams, :slug, :string, limit: 255, null: true
  end
end
