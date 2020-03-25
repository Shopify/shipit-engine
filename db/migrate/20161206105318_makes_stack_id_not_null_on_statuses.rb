# typed: false
class MakesStackIdNotNullOnStatuses < ActiveRecord::Migration[5.0]
  def change
    change_column_null :statuses, :stack_id, false
  end
end
