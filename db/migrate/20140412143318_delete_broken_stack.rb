class DeleteBrokenStack < ActiveRecord::Migration
  def change
    Stack.where(repo_owner: 'github.com/shopify').update_all(repo_owner: 'shopify')
  end
end
