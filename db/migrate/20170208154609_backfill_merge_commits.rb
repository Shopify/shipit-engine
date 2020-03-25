# typed: false
class BackfillMergeCommits < ActiveRecord::Migration[5.0]
  def change
    ActiveRecord::Base.no_touching do
      Shipit::Commit.find_in_batches do |commits|
        commits.each do |commit|
          commit.identify_pull_request
          commit.save!
        end
        print '.'
      end
    end
  end
end
