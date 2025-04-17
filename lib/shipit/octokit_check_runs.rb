# frozen_string_literal: true

module OctokitCheckRuns
  def check_runs(repo, sha, options = {})
    paginate("#{Octokit::Repository.path(repo)}/commits/#{sha}/check-runs", options)
  end
end

Octokit::Client.include(OctokitCheckRuns)
