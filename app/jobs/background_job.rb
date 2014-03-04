class BackgroundJob
  def self.perform(*args)
    if options = args.extract_options!
      args = [*args, options.with_indifferent_access]
    end

    new.perform(*args)
  end

  def logger
    Rails.logger
  end
end
