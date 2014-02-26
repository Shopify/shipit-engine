class Deploy < ActiveRecord::Base
  belongs_to :repo
  belongs_to :commit
end
