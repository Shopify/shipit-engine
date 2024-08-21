# frozen_string_literal: true

module Shipit
  class ContinuousDeliverySchedulesController < ShipitController
    before_action :load_stack

    def show
      @continuous_delivery_schedule = @stack.continuous_delivery_schedule || @stack.build_continuous_delivery_schedule
    end

    def update
      @continuous_delivery_schedule = @stack.continuous_delivery_schedule || @stack.build_continuous_delivery_schedule
      @continuous_delivery_schedule.assign_attributes(continuous_delivery_schedule_params)

      if @continuous_delivery_schedule.save
        flash[:success] = "Successfully updated"
        redirect_to(stack_continuous_delivery_schedule_path)
      else
        flash.now[:warning] = "Check form for errors"
        render(:show, status: :unprocessable_entity)
      end
    end

    private

    def load_stack
      @stack = Stack.from_param!(params[:id])
    end

    def continuous_delivery_schedule_params
      params.require(:continuous_delivery_schedule).permit(
        :timezone_name,
        *Shipit::ContinuousDeliverySchedule::DAYS.flat_map do |day|
          [
            "#{day}_start",
            "#{day}_end",
            "#{day}_enabled",
          ]
        end
      )
    end

    def operation_param
      params.require(:continuous_delivery_schedule).permit(:_operation)[:_operation]
    end
  end
end
