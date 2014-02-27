class Stack < ActiveRecord::Base
  has_many :commits
  has_many :deploys
end
