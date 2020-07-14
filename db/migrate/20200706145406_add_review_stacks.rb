class AddReviewStacks < ActiveRecord::Migration[6.0]
  def up
    add_column :stacks, :type, :string, default: "Shipit::Stack"
    add_index :stacks, :type

    transform_auto_provisioned_stacks_to_review_stacks
  end

  def down
    transform_review_stacks_to_auto_provisioned_stacks

    remove_index :stacks, :type
    remove_column :stacks, :type
  end

  def transform_auto_provisioned_stacks_to_review_stacks
    Shipit::Stack
      .where(auto_provisioned: :true)
      .update_all(type: "Shipit::ReviewStack")
  end

  def transform_review_stacks_to_auto_provisioned_stacks
    Shipit::Stack
      .where(type: "Shipit::ReviewStack")
      .update_all(auto_provisioned: true)
  end
end
