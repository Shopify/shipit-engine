# typed: false
class SchemaConstraintsCleanup < ActiveRecord::Migration[4.2]
  # Set reasonable size limit to a bunch of indexed string columns. They were defaulted to 255
  def change
    change_column :github_hooks, :event, :string, limit: 50, null: false # The biggest existing event is 27
    change_column :github_hooks, :organization, :string, limit: 39 # https://github.com/Shopify/shipit-engine/blob/d9aa8d54902de9ab3bd1ea4503003cca7df5d431/app/models/stack.rb#L4

    change_column :stacks, :repo_name, :string, limit: 100, null: false # https://github.com/Shopify/shipit-engine/blob/d9aa8d54902de9ab3bd1ea4503003cca7df5d431/app/models/stack.rb#L5
    change_column :stacks, :repo_owner, :string, limit: 39, null: false # https://github.com/Shopify/shipit-engine/blob/d9aa8d54902de9ab3bd1ea4503003cca7df5d431/app/models/stack.rb#L4
    change_column :stacks, :environment, :string, limit: 50, null: false, default: 'production'

    change_column :tasks, :status, :string, limit: 10, null: false, default: 'pending'

    change_column :teams, :organization, :string, limit: 39 # https://github.com/Shopify/shipit-engine/blob/d9aa8d54902de9ab3bd1ea4503003cca7df5d431/app/models/stack.rb#L4
    change_column :teams, :slug, :string, limit: 50 # No real limit GH side AFAICT, but come on...

    change_column :users, :login, :string, limit: 39 # https://github.com/Shopify/shipit-engine/blob/d9aa8d54902de9ab3bd1ea4503003cca7df5d431/app/models/stack.rb#L4
  end
end
