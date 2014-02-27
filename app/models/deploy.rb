class Deploy < ActiveRecord::Base
  belongs_to :stack
  belongs_to :since_commit, class_name: "Commit"
  belongs_to :until_commit, class_name: "Commit"

  def self.trigger(until_commit)
    
  end

  def working_directory
    File.join(stack.deploys_path, id.to_s)
  end
end
