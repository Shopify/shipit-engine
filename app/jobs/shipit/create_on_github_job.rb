module Shipit
  class CreateOnGithubJob < BackgroundJob
    include BackgroundJob::Exclusive

    queue_as :default

    def perform(record)
      record.create_on_github!
    end
  end
end
