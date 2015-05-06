class ChunksController < ShipsterController
  include ChunksHelper

  before_action :load_stack
  before_action :load_task
  before_action :load_output_chunks

  respond_to :json

  def index
    respond_with(@output_chunks)
  end

  def tail
    respond_with(url: next_chunks_url(@task), task: @task, chunks: @output_chunks)
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
