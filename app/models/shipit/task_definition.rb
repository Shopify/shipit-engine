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

    attr_reader :id, :action, :description, :steps, :checklist, :variables
    alias_method :to_param, :id

    def initialize(id, config)
      @id = id
      @action = config['action']
      @description = config['description'] || ''
      @steps = config['steps'] || []
      @variables = task_variables(config['variables'] || [])
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
        variables: variables.map(&:to_h),
        checklist: checklist,
        allow_concurrency: allow_concurrency?,
      }
    end

    def filter_envs(env)
      EnvironmentVariables.with(env).permit(variables)
    end

    def variables_with_defaults
      @variables_with_defaults ||= variables.select { |v| v.default.present? }
    end

    private

    def task_variables(config_variables)
      config_variables.map(&VariableDefinition.method(:new))
    end
  end
end
