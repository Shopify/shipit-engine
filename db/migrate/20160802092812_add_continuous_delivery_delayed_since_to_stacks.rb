class AddContinuousDeliveryDelayedSinceToStacks < ActiveRecord::Migration
  def change
    add_column :stacks, :continuous_delivery_delayed_since, :datetime, null: true
  end
end
