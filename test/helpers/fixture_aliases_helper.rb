module FixtureAliasesHelper
  def deploys(*args)
    tasks(*args)
  end

  def rollbacks(*args)
    tasks(*args)
  end
end
