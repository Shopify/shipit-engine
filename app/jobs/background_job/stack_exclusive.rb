module BackgroundJob::StackExclusive
  def self.extended(base)
    base.extend(Resque::Plugins::Workers::Lock)
  end

  def self.lock_workers(params)
    "stack-#{params[:stack_id]}"
  end
end
