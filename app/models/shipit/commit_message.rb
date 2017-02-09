module Shipit
  class CommitMessage
    GITHUB_MERGE_COMMIT_PATTERN = %r{\AMerge pull request #(?<pr_id>\d+) from [\w\-./]+\n\n(?<pr_title>.*)}

    def initialize(text)
      @text = text
    end

    def pull_request?
      !!parsed
    end

    def pull_request_number
      parsed && parsed['pr_id'].to_i
    end

    def pull_request_title
      parsed && parsed['pr_title']
    end

    def to_s
      @text
    end

    private

    def parsed
      return @parsed if defined?(@parsed)
      @parsed = to_s.match(GITHUB_MERGE_COMMIT_PATTERN)
    end
  end
end
