class DeploySpec
  class FileSystem < DeploySpec
    include BundlerDiscovery
    include CapistranoDiscovery
    include RubygemsDiscovery

    def initialize(app_dir, env)
      @app_dir = Pathname(app_dir)
      @env = env
    end

    private

    def config(*)
      @config ||= load_config
      super
    end

    def load_config
      read_config(file("shipit.#{@env}.yml")) || read_config(file("shipit.yml"))
    end

    def read_config(path)
      SafeYAML.load(path.read) if path.exist?
    end

    def file(path)
      @app_dir.join(path)
    end

  end
end
