require 'pry'

class RemoteWebhooksController < ApplicationController
  before_action :load_stack

  def create
    @remote_webhook = RemoteWebhook.create(create_params)
    redirect_to stack_settings_path(@stack)
  end

  def create_params
    params.require(:remote_webhook).permit(:endpoint, :action).merge(stack_id: @stack.id)
  end

  def load_stack
    @stack ||= Stack.from_param(params[:stack_id])
  end
end
