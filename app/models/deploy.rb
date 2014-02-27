class Deploy < ActiveRecord::Base
  belongs_to :stack
  belongs_to :since_commit, class_name: "Commit"
  belongs_to :until_commit, class_name: "Commit"
end
