class DeploySpec
  module PypiDiscovery
    def discover_deploy_steps
      discover_pypi || super
    end

    def discover_pypi
      publish_egg if egg?
    end

    def discover_review_checklist
      discover_pypi_checklist || super
    end

    def discover_pypi_checklist
      [%(<strong>Don't forget to add a tag before deploying!</strong> You can do this with:
        git tag -a -m "Version <strong>x.y.z</strong>" v<strong>x.y.z</strong> && git push --tags)] if egg?
    end

    def egg?
      setup_dot_py.exist?
    end

    def setup_dot_py
      file('setup.py')
    end

    def publish_egg
      ["assert-egg-version-tag #{setup_dot_py}", 'python setup.py register sdist upload']
    end
  end
end
