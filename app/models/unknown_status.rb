class UnknownStatus
  attr_reader :commit

  def initialize(commit)
    @commit = commit
  end

  def state
    'unknown'
  end

  def pending?
    false
  end

  def success?
    false
  end

  def error?
    false
  end

  def failure?
    false
  end

  def group?
    false
  end

  def target_url
    nil
  end

  def description
    ''
  end

  def context
    'ci/unknown'
  end

  def to_partial_path
    'statuses/status'
  end
end
