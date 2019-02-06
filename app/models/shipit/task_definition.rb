module Shipit
  class TaskDefinition
    NotFound = Class.new(StandardError)

    class << self
      def load(payload)
        return if payload.blank?
        json = JSON.parse(payload)
        new(json.delete('id'), json)
      end

      def dump(definition)
        return if definition.blank?
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
      @title = config['title']
    end

    def render_title(env)
      if @title
        @title % env.symbolize_keys
      else
        action
      end
    rescue KeyError
      "This task (title: #{@title}) cannot be shown due to an incorrect variable name. Check your shipit.yml file"
    end

    def allow_concurrency?
      @allow_concurrency
    end

    def as_json
      {
        id: id,
        action: action,
        title: @title,
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
      @variables_with_defaults ||= variables.select(&:default_provided?)
    end

    private

    def task_variables(config_variables)
      config_variables.map(&VariableDefinition.method(:new))
    end
  end
end
