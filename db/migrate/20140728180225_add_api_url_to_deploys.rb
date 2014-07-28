class AddApiUrlToDeploys < ActiveRecord::Migration
  def change
    add_column :deploys, :api_url, :string
  end
end
