class Commit < ActiveRecord::Base
  belongs_to :stack
  has_many :deploys
  belongs_to :author, class_name: "User"
  belongs_to :committer, class_name: "User"
end
