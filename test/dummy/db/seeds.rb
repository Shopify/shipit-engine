require 'faker'
require 'fakeweb'

# Sometimes on Travis the background job runs immediately so provide a response to fake hooks
FakeWeb.register_uri(:post, %r{https://example\.com/}, status: %w(200 OK))

# Cheap hack to allow rake db:seed to work
module Shipit
  Stack.send(:define_method, :setup_hooks) {}
  Stack.send(:define_method, :sync_github) {}
  Commit.send(:define_method, :fetch_stats!) {}
  Commit.send(:define_method, :refresh_statuses!) {}

  users = 3.times.map do
    User.create!(
      name:  Faker::Name.name,
      email: Faker::Internet.email,
      login: Faker::Internet.user_name,
    )
  end

  stacks = 3.times.map do
    Stack.create!(
      repo_name:  Faker::Internet.domain_name.parameterize,
      repo_owner: Faker::Company.name.parameterize,
      deploy_url:  "https://#{Faker::Internet.domain_name.parameterize}.#{Faker::Internet.domain_suffix}/",
      cached_deploy_spec: DeploySpec.load(%(
        {
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
          "deploy": {
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
        additions: Faker::Number.number(3),
        deletions: Faker::Number.number(3),
      )

      Status.create!(
        state: %w(pending success error failure).sample,
        context: 'ci/travis',
        description: "Your tests ran on travis-ci",
        target_url: "https://example.com",
        commit_id: commit.id,
        created_at: Time.now,
        updated_at: Time.now,
      )

      if (i % 5) == 0
        Status.create!(
          state: %w(pending success error failure).sample,
          context: 'ci/circle',
          description: "Your tests ran on circle-ci",
          target_url: "https://example.com",
          commit_id: commit.id,
          created_at: Time.now,
          updated_at: Time.now,
        )
      end
    end
  end

  def create_chunks
    100.times.map do
      status = "\x1b[%s;1m[ %s ]\x1b[0m" % [["31", "error"], ["32", "success"]].sample
      OutputChunk.new(text: "[ #{Faker::Date.backward} ] #{status} #{Faker::Lorem.paragraph}\n")
    end
  end

  stacks.each do |stack|
    stack.commits.limit(45).each_slice(2).each do |commits|
      deploy = stack.deploys.create!(
        since_commit_id: commits.first.id,
        until_commit_id: commits.last.id,
        status:          "success",
        chunks:          create_chunks,
        additions: Faker::Number.number(3),
        deletions: Faker::Number.number(3),
        user: users.sample,
      )
      deploy.write("$ cap production deploy SHA=yolo")
    end

    last_deploy = stack.deploys.last
    stack.rollbacks.create!(
      since_commit_id: last_deploy.until_commit_id,
      until_commit_id: last_deploy.since_commit_id,
      status: 'success',
      user: users.sample,
      chunks: create_chunks,
    )

    stack.tasks.create!(
      since_commit_id: stack.last_deployed_commit.id,
      until_commit_id: stack.last_deployed_commit.id,
      status: "success",
      user: users.sample,
      definition: TaskDefinition.new('restart',
        'action' => 'Restart application',
        'description' => 'Restart unicorns and resques',
        'steps' => ['cap $ENVIRONMENT restart'],
      ),
      chunks: create_chunks,
    )
  end
end
