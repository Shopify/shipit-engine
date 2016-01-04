module Shipit
  class CommitChecksController < ShipitController
    params do
      accepts :since, Integer, default: 0
    end
    def tail
      output = checks.output(since: params.since)
      next_offset = params.since + output.bytesize
      url = stack_tail_commit_checks_path(stack, sha: commit.sha, since: next_offset) unless checks.finished?

      render json: {url: url, output: output, status: checks.status}
    end

    private

    delegate :checks, to: :commit

    def commit
      @commit ||= stack.commits.find_by_sha!(params[:sha])
    end

    def stack
      @stack ||= Stack.from_param!(params[:stack_id])
    end
  end
end
