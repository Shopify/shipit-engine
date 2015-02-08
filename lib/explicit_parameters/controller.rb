module ExplicitParameters
  module Controller
    extend ActiveSupport::Concern

    class << self
      attr_accessor :last_parameters
    end

    included do
      self.parameters = {}
      rescue_from ExplicitParameters::InvalidParameters, with: :render_parameters_error
    end

    module ClassMethods
      attr_accessor :parameters

      def method_added(action)
        return unless Controller.last_parameters
        parameters[action.to_s] = Controller.last_parameters
        Controller.last_parameters = nil
      end

      def params(&block)
        Controller.last_parameters = ExplicitParameters::Parser.new(&block)
      end

      def parameters_for(action)
        parameters[action] or raise MissingParametersDeclaration.new("No parameters declared for #{action.inspect}")
      end

      def parse_parameters_for(action_name, params)
        parameters_for(action_name).from_param(params)
      end
    end

    private

    def params
      @validated_params ||= self.class.parse_parameters_for(action_name, super)
    end

    def render_parameters_error(error)
      render json: error.message, status: :bad_request
    end
  end
end
