class DeploySerializer < TaskSerializer
  attributes :additions, :deletions

  def html_url
    stack_deploy_url(object.stack, object)
  end

  def type
    :deploy
  end
end
