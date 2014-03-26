class Menu
  class Repo

    attr_reader :name, :stacks

    def initialize(name, stacks)
      @name = name
      @stacks = stacks
    end

  end

  class Owner

    attr_reader :name

    def initialize(name, stacks)
      @name = name
      @stacks = stacks
    end

    def repos
      @repos ||= @stacks.group_by(&:repo_name).map { |name, stacks| Repo.new(name, stacks) }
    end

  end

  def owners
    @owners = Stack.all.to_a.group_by(&:repo_owner).map { |name, stacks| Owner.new(name, stacks) }
  end

  def updated_at
    Rails.cache.fetch('menu:updated_at') { Stack.maximum(:created_at) }
  end

  def self.bump_cache
    Rails.cache.write('menu:updated_at', Time.now)
  end

end