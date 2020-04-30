# frozen_string_literal: true
namespace :teams do
  desc "Import the members of each team configured through the github.oauth.teams config"
  task fetch: :environment do
    Shipit.github_teams.each do |team|
      puts "Fetching @#{team.handle} members"
      begin
        team.refresh_members!
      rescue Octokit::Unauthorized, Octokit::NotFound => error
        puts "Failed to fetch @#{team.handle} members. Do you have enough permissions?"
        puts "#{error.class}: #{error.message}"
      end
    end
  end
end
