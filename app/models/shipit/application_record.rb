# typed: strong
module Shipit
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
