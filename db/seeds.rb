require 'faker'

users = 3.times.map do
  User.create!(
    :name  => Faker::Name.name,
    :email => Faker::Internet.email,
    :login => Faker::Internet.user_name
  )
end

stacks = 3.times.map do
  Stack.create!(
    :repo_name  => Faker::Internet.domain_name.parameterize,
    :repo_owner => Faker::Company.name.parameterize
  )
end

stacks.each do |stack|
  20.times do
    user = users.sample

    Commit.create!(
      :stack_id     => stack.id,
      :author_id    => user.id,
      :committer_id => user.id,
      :sha          => SecureRandom.hex(20),
      :message      => Faker::Company.catch_phrase,
      :state        => %w(pending success error failure).sample
    )
  end
end

deploys = []

stacks.each do |stack|
  stack.commits.limit(15).each_slice(5).each do |commits|
    chunks = 5.times.map { OutputChunk.new(:text => Faker::Lorem.paragraph) }
    deploys << stack.deploys.create!(
      :since_commit_id => commits.first.id,
      :until_commit_id => commits.last.id,
      :status          => "success",
      :output          => "$ cap production deploy SHA=yolo",
      :chunks          => chunks,
    )
  end
end
