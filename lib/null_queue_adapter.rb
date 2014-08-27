class NullQueueAdapter

  def self.enqueue(job, *)
    p [:enqueue, job]
  end

  def self.enqueue_at(*)
  end

end
