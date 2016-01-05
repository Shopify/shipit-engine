module Shipit
  class DeploySerializer < TaskSerializer
    has_many :commits

    attributes :additions, :deletions

    def html_url
      stack_deploy_url(object.stack, object)
    end

    def type
      :deploy
    end
  end
end
