# Review Stacks

A Review Stack is a dynamically managed stack whose lifecycle is tied to a Github Pull Request.

# Enabling Review Stacks

Review stacks can be enabled via the shipit-engine Repository UI.

1. Visit the shipit-engine Repository UI - `https://host-application/repositories`
1. Click on the project's repository
1. Check "Dynamically provision stacks for Pull Requests?"
1. Select the "Provisioning Behavior" appropriate for your project - most likely "Allow All"
1. Click "Save"

# Configuring Review Stack behavior

shipit-engine support three distinct behaviors for determining which Pull Requests should be considered for Review Stack creation.

1. "Allow All" - shipit-engine will create a Review Stack for every new Pull Requests.
1. "Allow With Label" - when creating or updating a Pull Request, the user must add a label matching the `Shipit::Repository`'s "provisioning_label" attribute in order for shipit-engine to dynamically create/manage a Review Stack - an opt-in strategy.
1. "Prevent With Label" - when creating or updating a Pull Request, the user must add a label matching the `Shipit::Repository`'s "provisoining_label" attribute in order to **prevent** shipit-engine from dynamically creating/managing a Review Stack - an opt-out strategy.

# Provisioning and deprovisioning Review Stack instances

Review Stacks will need an instance into which they are deployed. For some this might be a Heroku instance, for others it might be a Kubernetes namespace, etc. shipit-engine allows the host application to define `ProvisioningHandler`s to define how Review Stacks should provisoing/deprovision their instances.

For example, imagine a repository which deploys to a Kubernetes cluster. The host application could register a Kubernetes provisioning handler to take care of setting-up and tearing-down Kubernetes resources for a stack:

Define a provisioning Handler:

```ruby
# <path-to-host-application>/app/provisioning_handlers/kubernetes_provisioning_handler.rb
class KubernetesProvisioningHandler < Shipit::ProvisioningHandler::Base
  def up
    # allocate a namespace, copy resources, etc
  end

  def down
    # delete the namespace, etc.
  end
end
```

`ProvisioningHandler`s may provide a predicate to determine if a stack should be provisioned. For example a host application _may_ use this interrogate external systems to validate that ample resources are available to handle the new review stack before actual allocation of resources is made. Extending the above example, the ` KubernetesProvisioningHandler` _might_ first ask the cluster if it can provision the review stack:

```ruby
# <path-to-host-application>/app/provisioning_handlers/kubernetes_provisioning_handler.rb
class KubernetesProvisioningHandler < Shipit::ProvisioningHandler::Base
  def up
    # allocate a namespace, copy resources, etc
  end

  def down
    # delete the namespace, etc.
  end

  def provision?
    # interrogate status of resources to determin if ample head room exists to provision a new review stack
  end
end
```

In the case where a `ProvisioningHandler` does not specify a `#provision?` predicate, the provisioning handler will always attempt to provision a Review Stack.

The host application **MUST** `#register` - whitelist - the custom ProvisioningHandler in the `Shipit::ProvisioningHandler` registry. This will  most likely happen as part of a shipit-engine initialization routine in the host application. For example:

```ruby
# <path-to-host-application>/config/initializers/shipit.rb
ActiveSupport::Reloader.to_prepare do
  ...
  Shipit::ProvisioningHandler.register(KubernetesProvisioningHandler)
end
```
The custom `KubernetesProvisioningHandler` can then be used in a project's `shipit.yml`:

```yaml
# <path-to-managed-appliction>/shipit.yml
provision:
  handler_name: KubernetesProvisioningHandler

deploy:
  override: <deployment-script>
```

Now all Review Stacks for this repository will use the `KubernetesProvisioningHandler` to (de)provision their instances.

## Default `ProvisioningHandler`s

Register a host-application-wide default provisioning handler - IE how repositories which don't explicitly define a provisoining handler will be provisioned:

```ruby
# <path-to-host-application>/config/initializers/shipit.rb
ActiveSupport::Reloader.to_prepare do
  ...
  Shipit::ProvisioningHandler.default = KubernetesProvisioningHandler
end
```

A default, no-op provisioning handler - `Shipit::ProvisioningHandler::Base` - is provided. When the name of an unregistered handler is requested from the `Shipit::ProvisioningHandler` the `Shipit::ProvisioningHandler::UnregisteredProvisioningHandler` is used. Effectively, this prevents transitions of the provisioning state machine and locks the Review Stack indicating that an attempt to provision the Review Stack instance was made, but can't be completed until the Review Stack's Provisioning Handler is registered.

The ProvisioningHandler for a give stack is discovered at runtime using the following order of precedence:

1. shipit.yml - `handler_name:` value
1. Host-application-specific default override - `Shipit::ProvisioningHandler.default = ...`
1. no-op default - `ProvisioningHandler::Base`
