class TransformReviewMergeRequestsIntoPullRequests < ActiveRecord::Migration[6.0]
  def change
    Shipit::MergeRequest.joins(:stack).where(review_request: true).find_each do |merge_request|
      stack = merge_request.stack
      pull_request_attribute_list = %w(
       stack_id
       number
       title
       github_id
       api_url
       state
       additions
       deletions
       user_id
      )
      pull_request_attributes = merge_request.attributes.keep_if do |key, value|
          value.present? &&
            pull_request_attribute_list.include?(key)
      end

      pull_request = Shipit::PullRequest.create!(pull_request_attributes)
      pull_request.assignees = merge_request.assignees

      merge_request.destroy!
    end
  end
end
