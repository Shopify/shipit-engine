class LowerCaseOwnerAndRepo < ActiveRecord::Migration
  def change
    Stack.find_each do |stack|
      stack.repo_owner = stack.repo_owner
      stack.repo_name = stack.repo_name
      stack.save!
    end
  end
end
