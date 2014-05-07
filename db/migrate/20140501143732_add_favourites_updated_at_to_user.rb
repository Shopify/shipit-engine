class AddFavouritesUpdatedAtToUser < ActiveRecord::Migration
  def change
    add_column :users, :favourites_updated_at, :datetime
  end
end
