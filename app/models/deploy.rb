class Deploy < ActiveRecord::Base
  belongs_to :stack
  belongs_to :commit
end
