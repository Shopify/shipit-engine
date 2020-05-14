# frozen_string_literal: true
namespace :shipit do
  desc "Deploy from a running instance. "
  task deploy: :environment do
    stack = ENV['stack']
    revision = ENV['revision']

    raise ArgumentError, 'The first argument has to be a stack, e.g. shopify/shipit/production' if stack.nil?
    raise ArgumentError, 'The second argument has to be a revision' if revision.nil?

    module Shipit
      class Task
        def write(text)
          p(text)
          chunks.create!(text: text)
        end
      end
    end

    Shipit::Stack.run_deploy_in_foreground(stack: stack, revision: revision)
  rescue ArgumentError
    p("Use this command as follows:")
    p("bundle exec rake shipit:deploy stack='shopify/shipit/production' revision='$SHA'")
    raise
  end
end
