namespace :dev do
  desc "Appends chunks to the last deploy, or specify with DEPLOY=id"
  task stream: :environment do
    require 'faker'
    logger = Logger.new(STDOUT)

    deploy = Shipit::Deploy.find(ENV['DEPLOY']) if ENV['DEPLOY']
    deploy ||= Deploy.last

    raise "Couldn't find Deploy" unless deploy

    deploy.update_attribute(:output, nil)

    logger.info "Starting to stream data to deploy ##{deploy.id}"

    loop do
      sentence = Faker::Lorem.sentence.split.map do |word|
        if rand(4).zero?
          "\e[#{rand(30..37)}m#{word}\e[0m"
        else
          word
        end
      end.join(' ')

      logger.error sentence

      deploy.chunks.create(text: sentence + "\n")
      sleep 1
    end
  end
end
