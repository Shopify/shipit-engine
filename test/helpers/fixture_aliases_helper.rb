# typed: false
module FixtureAliasesHelper
  def shipit_deploys(*args)
    shipit_tasks(*args)
  end

  def shipit_rollbacks(*args)
    shipit_tasks(*args)
  end
end
