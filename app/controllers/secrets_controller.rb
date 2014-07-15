class SecretsController < ApplicationController

  before_action :load_stack

  def create
    @stack.secrets = @stack.secrets.merge(secret_params)
    flash = @stack.save ? {success: 'Secret successfully saved'} : {error: 'Secret could not be saved'}
    redirect_to settings_stack_path(@stack), flash
  end

  def destroy
    @stack.secrets = @stack.secrets.except(params[:id])
    flash = @stack.save ? {success: 'Secret successfully removed'} : {error: 'Secret could not be removed'}
    redirect_to settings_stack_path(@stack), flash
  end

  private

  def secret_params
    secret = params.require(:secret).permit(:key, :secret_value)
    {secret[:key] => secret[:secret_value]}
  end

  def load_stack
    @stack = Stack.from_param(params[:stack_id])
  end

end
