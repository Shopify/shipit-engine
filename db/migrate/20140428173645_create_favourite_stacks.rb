class CreateFavouriteStacks < ActiveRecord::Migration
  def change
    create_table :favourite_stacks do |t|
      t.belongs_to :user, index: true
      t.belongs_to :stack, index: true

      t.timestamps
    end
  end
end
