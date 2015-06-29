class ChunksController < ShipitController
  include ChunksHelper

  respond_to :json

  before_action :load_stack
  before_action :load_task
  before_action :load_output_chunks

  def index
    respond_with(@output_chunks)
  end

  def tail
    output = @output_chunks.pluck(:text).join
    render json: {url: next_chunks_url(@task), status: @task.status, output: output}
  end

  private

  def load_output_chunks
    @output_chunks = @task.chunks.tail(params[:last_id])
  end

  def load_task
    @task = @stack.tasks.find(params[:task_id])
  end

  def load_stack
    @stack = Stack.from_param!(params[:stack_id])
  end
end
