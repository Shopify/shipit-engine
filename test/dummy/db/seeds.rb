require 'faker'

# Cheap hack to allow rake db:seed to work
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
  )
end

stacks.each do |stack|
  20.times do |i|
    user = users.sample

    commit = Commit.create!(
      stack_id:     stack.id,
      author_id:    user.id,
      committer_id: user.id,
      sha:          SecureRandom.hex(20),
      message:      Faker::Company.catch_phrase,
      authored_at:  Time.now,
      committed_at: Time.now,
    )

    Status.create!(
      state: %w(pending success error failure).sample,
      context: 'ci/travis',
      commit_id: commit.id,
      created_at: Time.now,
      updated_at: Time.now,
    )

    if (i % 5) == 0
      Status.create!(
        state: %w(pending success error failure).sample,
        context: 'ci/circle',
        commit_id: commit.id,
        created_at: Time.now,
        updated_at: Time.now,
      )
    end
  end
end

stacks.each do |stack|
  stack.commits.limit(15).each_slice(5).each do |commits|
    chunks = 5.times.map {
      status = "\x1b[%s;1m[ %s ]\x1b[0m" % [["31", "error"], ["32", "success"]].sample
      OutputChunk.new(text: "[ #{Faker::Date.backward} ] #{status} #{Faker::Lorem.paragraph}\n")
    }
    deploy = stack.deploys.create!(
      since_commit_id: commits.first.id,
      until_commit_id: commits.last.id,
      status:          "success",
      chunks:          chunks,
    )
    deploy.write("$ cap production deploy SHA=yolo")
  end
end
