# Quick money patch to make state_machine work with rails 4.1
# see https://github.com/pluginaweek/state_machine/pull/275
module StateMachine::Integrations::ActiveModel
  def around_validation(object)
    object.class.state_machines.transitions(object, action, :after => false).perform { yield }
  end
end
