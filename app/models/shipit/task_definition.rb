module Shipit
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

    attr_reader :id, :action, :description, :steps, :checklist
    alias_method :to_param, :id

    def initialize(id, config)
      @id = id
      @action = config['action']
      @description = config['description'] || ''
      @steps = config['steps'] || []
      @checklist = config['checklist'] || []
      @allow_concurrency = config['allow_concurrency'] || false
    end

    def allow_concurrency?
      @allow_concurrency
    end

    def as_json
      {
        id: id,
        action: action,
        description: description,
        steps: steps,
        checklist: checklist,
        allow_concurrency: allow_concurrency?,
      }
    end
  end
end
