# frozen_string_literal: true

module Shipit
  class Label < Record
    def self.find_or_create_from_github!(github_label)
      find_or_create_by!(name: github_label.name)
    end
  end
end
