# frozen_string_literal: true
class AddHeadReferenceToPullRequests < ActiveRecord::Migration[6.0]
  def change
    add_reference :pull_requests, :head
  end
end
