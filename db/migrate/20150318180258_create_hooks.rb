class CreateHooks < ActiveRecord::Migration
  def change
    create_table :hooks do |t|
      t.references :stack, null: true, default: nil, index: true
      t.string :url, null: false, limit: 4096
      t.string :content_type, null: false, limit: 4, default: 'json'
      t.string :secret, null: true
      t.string :events, null: false, default: ''
      t.boolean :insecure_ssl, default: false, null: false
      t.timestamps null: false
    end
  end
end
