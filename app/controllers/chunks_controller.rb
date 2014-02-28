class ChunksController < ApplicationController

  before_action :load_stack
  before_action :load_deploy
  before_action :load_output_chunks

  respond_to :json

  def index
    respond_with(@output_chunks)
  end

  private

  def load_output_chunks
    @output_chunks = @deploy.chunks
  end

  def load_deploy
    @deploy = @stack.deploys.find(params[:deploy_id])
  end

  def load_stack
    @stack = Stack.from_param(params[:stack_id])
  end
end
