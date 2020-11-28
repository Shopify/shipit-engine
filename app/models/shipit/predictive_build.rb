# frozen_string_literal: true

module Shipit
  class PredictiveBuild < Record
    belongs_to :pipeline
    has_many :predictive_branches
  end
end
