class Commands

  def self.git_version
    @git_version ||= begin
      `git --version` =~ /([\d\.]+)/
      raise 'git command not found' unless $1
      Gem::Version.new($1)
    end
  end

  delegate :git_version, to: :class

  def env
    Settings['env'] || {}
  end

  def git(*args)
    Command.new("git", *args)
  end

end
