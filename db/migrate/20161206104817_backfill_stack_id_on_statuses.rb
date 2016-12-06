class BackfillStackIdOnStatuses < ActiveRecord::Migration[5.0]
  def up
    Shipit::Commit.order(stack_id: :asc).find_in_batches do |commits|
      commits.group_by(&:stack_id).each do |stack_id, stack_commits|
        Shipit::Status.where(commit_id: stack_commits.map(&:id)).update_all(stack_id: stack_id)
      end
      print '.'
    end
  end

  def down
  end
end
