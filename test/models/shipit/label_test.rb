# frozen_string_literal: true

require "test_helper"

module Shipit
  class LabelTest < ActiveSupport::TestCase
    test ".find_or_create_from_github! creates new labels" do
      github_label = resource(
        {
          name: "pull-requests-label",
        }
      )

      assert_changes -> { Shipit::Label.count } do
        label = Label.find_or_create_from_github!(github_label)

        assert_equal "pull-requests-label", label.name
      end
    end

    test ".find_or_create_from_github! reuses existing labels" do
      label = shipit_labels(:deploy)
      github_label = resource(
        {
          name: label.name,
        }
      )

      assert_no_changes -> { Shipit::Label.count } do
        Label.find_or_create_from_github!(github_label)
      end
    end
  end
end
