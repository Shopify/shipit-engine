class TaskDefinition
  NotFound = Class.new(StandardError)

  class << self
    def load(payload)
      return unless payload.present?
      json = JSON.parse(payload)
      new(json.delete('id'), json)
    end

    def dump(definition)
      return unless definition.present?
      JSON.dump(definition.as_json)
    end
  end

  attr_reader :id, :action, :description, :steps

  def initialize(id, config)
    @id = id
    @action = config['action']
    @description = config['description'] || ''
    @steps = config['steps'] || []
  end

  def as_json
    {
      id: id,
      action: action,
      description: description,
      steps: steps,
    }
  end
end
