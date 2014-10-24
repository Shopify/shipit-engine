class RebuildStacksCachedDeploySpec < ActiveRecord::Migration
  def up
    Stack.pluck(:id).each do |id|
      Resque.enqueue(CacheDeploySpecJob, stack_id: id)
    end
  end

  def down
  end
end
