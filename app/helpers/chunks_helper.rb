module ChunksHelper
  def next_chunks_url
    tail_stack_deploy_chunks_path(@stack, @deploy, last_id: @deploy.chunks.last.id)
  end
end
