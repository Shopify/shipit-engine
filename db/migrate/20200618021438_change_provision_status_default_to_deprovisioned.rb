class ChangeProvisionStatusDefaultToDeprovisioned < ActiveRecord::Migration[6.0]
  def change
    change_column_default :stacks, :provision_status, :deprovisioned
  end
end
