class Status < ActiveRecord::Base
  belongs_to :commit
  after_save :update_commit_state

  def update_commit_state
    commit.denormalize_state
  end
end
