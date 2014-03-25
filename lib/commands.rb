class Commands

  def env
    Settings['env'] || {}
  end

  def git(*args)
    Command.new("git", *args)
  end

end
