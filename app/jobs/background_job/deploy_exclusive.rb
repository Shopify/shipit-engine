module BackgroundJob::DeployExclusive

  def self.extended(base)
    base.extend(Resque::Plugins::Workers::Lock)
  end

  def self.lock_workers(params)
    "stack-#{params[:deploy_id]}"
  end

end
