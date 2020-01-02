class CreateShipitExtraVariables < ActiveRecord::Migration[6.0]
  def change
    create_table :extra_variables do |t|
      t.string :key, null: false
      t.string :value, null: false
      t.references :stack, null: false, foreign_key: true, type: :integer

      t.timestamps
    end
  end
end
