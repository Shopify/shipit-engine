class Commit < ActiveRecord::Base
  belongs_to :stack
  has_many :deploys
end
