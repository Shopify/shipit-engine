module Shipit
  class ExtraVariable < ActiveRecord::Base
    belongs_to :stack
    validates :key, :value, presence: true
    validates :key, uniqueness: {
      scope: :stack_id,
      message: "key can only be defined once per stack",
      case_sensitive: false,
    }
  end
end
