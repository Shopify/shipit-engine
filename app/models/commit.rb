class Commit < ActiveRecord::Base
  belongs_to :repo
  has_many :deploys
end
