require 'faker'
require 'webmock'
include WebMock::API
WebMock.enable!
WebMock.allow_net_connect!

# Sometimes on Travis the background job runs immediately so provide a response to fake hooks
stub_request(:post, %r{https://example\.com/}).to_return(status: %w(200 OK))

# Cheap hack to allow rake db:seed to work
module Shipit
  Stack.send(:define_method, :sync_github) {}
  Commit.send(:define_method, :fetch_stats!) {}
  Commit.send(:define_method, :refresh_statuses!) {}
  Commit.send(:define_method, :refresh_check_runs!) {}
  ReleaseStatus.send(:define_method, :create_status_on_github!) {}
  CommitDeployment.send(:define_method, :schedule_create_on_github) {}
  CommitDeploymentStatus.send(:define_method, :schedule_create_on_github) {}

  users = 3.times.map do
    User.create!(
      name:  Faker::Name.name,
      email: Faker::Internet.email,
      login: Faker::Internet.user_name,
    )
  end

  stacks = 3.times.map do
    Stack.create!(
      repository: Repository.find_or_create_by(
        name:  Faker::Internet.domain_name.parameterize,
        owner: Faker::Company.name.parameterize
      ),
      branch: "main",
      deploy_url:  "https://#{Faker::Internet.domain_name.parameterize}.#{Faker::Internet.domain_suffix}/",
      cached_deploy_spec: DeploySpec.load(%(
        {
          "ci": {
            "hide": ["ci/hidden"],
            "require": ["ci/travis"],
            "allow_failures": ["ci/not-important"]
          },
          "dependencies": {
            "bundler": {
              "without": [
                "default",
                "production",
                "development",
                "test",
                "staging",
                "benchmark",
                "debug"
              ]
            },
            "override": [
              "bundle check --path=/tmp/bundler || bundle install --frozen --path=/tmp/bundler --retry=2 --without=default:production:development:test:staging:benchmark:debug"
            ]
          },
          "fetch": [
          ],
          "tasks": {
            "restart": {
              "action": "Restart application",
              "description": "Restart Thin and Resque.",
              "steps": [
                "bundle exec cap $ENVIRONMENT deploy:restart"
              ],
              "variables": [
                {"name": "SAFETY_DISABLED", "title": "Set to 1 to do stuff", "default": "0"}
              ],
              "checklist": [
                "Hold on your butts",
                "Eat some chips"
              ]
            }
          },
          "machine": {
            "environment": {
            },
            "directory": null
          },
          "review": {
            "checklist": [
              "Hold on your butts",
              "Eat some chips"
            ]
          },
          "status": {
            "context": "shipit/pre-production",
            "delay": 60
          },
          "deploy": {
            "max_commits": 3,
            "override": [
              "bundle exec cap $ENVIRONMENT deploy"
            ]
          },
          "rollback": {
            "override": [
              "bundle exec cap $ENVIRONMENT deploy:rollback"
            ]
          }
        }
      )),
    )
  end

  stacks.each do |stack|
    50.times do |i|
      user = users.sample

      commit = Commit.create!(
        stack_id:     stack.id,
        author_id:    user.id,
        committer_id: user.id,
        sha:          SecureRandom.hex(20),
        message:      Faker::Company.catch_phrase,
        authored_at:  Time.now,
        committed_at: Time.now,
        additions: Faker::Number.number(digits: 3),
        deletions: Faker::Number.number(digits: 3),
      )

      if (i % 4) != 0
        Status.create!(
          state: %w(pending success error failure).sample,
          context: 'ci/travis',
          description: "Your tests ran on travis-ci",
          target_url: "https://example.com",
          commit_id: commit.id,
          stack_id: commit.stack_id,
          created_at: Time.now,
          updated_at: Time.now,
        )
      end

      if (i % 5) == 0
        Status.create!(
          state: %w(pending success error failure).sample,
          context: 'ci/circle',
          description: "Your tests ran on circle-ci",
          target_url: "https://example.com",
          commit_id: commit.id,
          stack_id: commit.stack_id,
          created_at: Time.now,
          updated_at: Time.now,
        )
      end
    end

    stack.merge_requests.create!(
      number: Faker::Number.number(digits: 3),
      title: Faker::Company.catch_phrase,
      merge_status: 'pending',
      merge_requested_at: 5.minute.ago,
      merge_requested_by: users.sample,
      github_id: Faker::Number.number(digits: 8),
      api_url: 'https://api.github.com/repos/shopify/shipit-engine/pulls/62',
      state: 'open',
      branch: "feature-#{Faker::Number.number(digits: 3)}",
      head_id: nil,
      mergeable: true,
      additions: Faker::Number.number(digits: 3),
      deletions: Faker::Number.number(digits: 3),
    )
  end

  def write_output(task)
    100.times do
      status = "\x1b[%s;1m[ %s ]\x1b[0m" % [["31", "error"], ["32", "success"]].sample
      task.write("[ #{Faker::Date.backward} ] #{status} #{Faker::Lorem.paragraph}\n")
    end
  end

  stacks.each do |stack|
    stack.commits.limit(45).each_slice(2).each do |commits|
      deploy = stack.deploys.create!(
        since_commit_id: commits.first.id,
        until_commit_id: commits.last.id,
        status:          "success",
        additions: Faker::Number.number(digits: 3),
        deletions: Faker::Number.number(digits: 3),
        started_at: Random.rand(15.minutes.to_i).seconds.ago,
        ended_at: Time.now.utc,
        user: users.sample,
      )
      write_output(deploy)
      deploy.write("$ cap production deploy SHA=yolo")
    end

    last_deploy = stack.deploys.last
    rollback = stack.rollbacks.create!(
      deploy: last_deploy,
      since_commit_id: last_deploy.until_commit_id,
      until_commit_id: last_deploy.since_commit_id,
      status: 'success',
      user: users.sample,
      started_at: Random.rand(15.minutes.to_i).seconds.ago,
      ended_at: Time.now.utc,
    )
    write_output(rollback)

    provision_task = stack.tasks.create!(
      status: "pending",
      user: users.sample,
      definition: TaskDefinition.new('provision',
        'action' => 'Provision some resources',
        'description' => 'Provisions servers for the application to be deployed to',
        'steps' => ['./provision.sh'],
      ),
      started_at: Random.rand(15.minutes.to_i).seconds.ago,
    )
    write_output(provision_task)

    restart_task = stack.tasks.create!(
      status: "success",
      user: users.sample,
      definition: TaskDefinition.new('restart',
        'action' => 'Restart application',
        'description' => 'Restart unicorns and resques',
        'steps' => ['cap $ENVIRONMENT restart'],
      ),
      started_at: Random.rand(15.minutes.to_i).seconds.ago,
      ended_at: Time.now.utc,
    )
    write_output(restart_task)
  end
end
