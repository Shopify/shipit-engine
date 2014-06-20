class AddStackUndeployedCommitsCount < ActiveRecord::Migration
  def up
    add_column :stacks, :undeployed_commits_count, :integer, default: 0, null: false
    Stack.update_all('undeployed_commits_count = IFNULL((SELECT COUNT(`commits`.`stack_id`) FROM `commits` where commits.id > IFNULL((select until_commit_id from deploys where deploys.stack_id = commits.stack_id order by id desc limit 1), 0) and `commits`.`detached` = 0 and commits.stack_id = stacks.id GROUP BY commits.stack_id), 0)')
  end

  def down
    remove_column :stacks, :undeployed_commits_count
  end
end
