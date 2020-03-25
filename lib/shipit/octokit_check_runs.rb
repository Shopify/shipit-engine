# typed: false
module OctokitCheckRuns
  def check_runs(repo, sha, options = {})
    paginate "#{Octokit::Repository.path repo}/commits/#{sha}/check-runs", options.reverse_merge(
      accept: 'application/vnd.github.antiope-preview+json',
    )
  end
end

Octokit::Client.include(OctokitCheckRuns)
