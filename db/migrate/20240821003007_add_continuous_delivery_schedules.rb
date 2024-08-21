class AddContinuousDeliverySchedules < ActiveRecord::Migration[7.1]
  def change
    create_table(:continuous_delivery_schedules) do |t|
      t.references(:stack, null: false, index: { unique: true })
      %w[sunday monday tuesday wednesday thursday friday saturday].each do |day|
        t.boolean("#{day}_enabled", null: false, default: true)
        t.time("#{day}_start", null: false, default: "00:00")
        t.time("#{day}_end", null: false, default: "23:59")
      end
      t.timestamps
    end
  end
end
