class CreateMemberships < ActiveRecord::Migration
  def change
    create_table :memberships do |t|
      t.references :team, foreign_key: true
      t.references :user, index: true, foreign_key: true
      t.timestamps null: false
      t.index %i(team_id user_id), unique: true
    end
  end
end
