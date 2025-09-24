# Shipit - Documentation
[![Build Status](https://travis-ci.org/Shopify/shipit-engine.svg?branch=master)](https://travis-ci.org/Shopify/shipit-engine)
[![Gem Version](https://badge.fury.io/rb/shipit-engine.svg)](http://badge.fury.io/rb/shipit-engine)

**Shipit** is a deployment tool that makes shipping code better for everyone. It's especially great for large teams of developers and designers who work together to build and deploy GitHub repos. You can use it to:

* Add new applications to your deployment environment without having to change core configuration files repeatedly &mdash; `shipit.yml` is basically plug and play
* Control the pace of development by pushing, locking, and rolling back deploys from within Shipit
* Enforce checklists and provide monitoring right at the point of deployment.

Shipit is compatible with just about anything that you can deploy using a script. It natively detects stacks using [bundler](http://bundler.io/) and [Capistrano](http://capistranorb.com/), and it has tools that make it easy to deploy to [Heroku](https://www.heroku.com/) or [RubyGems](https://rubygems.org/). At Shopify, we've used Shipit to synchronize and deploy hundreds of projects across dozens of teams, using Python, Rails, RubyGems, Java, and Go.

This guide aims to help you [set up](#installation-and-setup), [use](#using-shipit), and [understand](#reference) Shipit.

*Shipit requires a database (MySQL, PostgreSQL or SQLite3), Redis, and Ruby 2.6 or superior.*

* * *
## Table of contents

### I. INSTALLATION & SETUP

* [Installation](#installation)
* [Updating an existing installation](#updating-shipit)

### II. USING SHIPIT

* [Adding stacks](#adding-stacks)
* [Working on stacks](#working-on-stacks)
* [Configuring stacks](#configuring-stacks)

### III. REFERENCE

* [Format and content of shipit.yml](#configuring-shipit)
* [Script parameters](#script-parameters)
* [Configuring providers](#configuring-providers)
* [Free samples](/examples/shipit.yml)

### IV. INTEGRATING

* [Registering webhooks](#integrating-webhooks)

### V. CONTRIBUTING

* [Instructions](#contributing-instructions)
* [Local development](#contributing-local-dev)

* * *

## I. INSTALLATION & SETUP {#installation-and-setup}

### Installation

To create a new Shipit installation you can follow the [setup guide](docs/setup.md).

### Updating an existing installation {#updating-shipit}

1. If you locked the gem to a specific version in your Gemfile, update it there.
2. Update the `shipit-engine` gem with `bundle update shipit-engine`.
3. Install new migrations with `rake shipit:install:migrations db:migrate`.

### Specific updates requiring more steps {#special-update}

If you are upgrading from `0.21` or older, you will have to update the configuration. Please follow [the dedicated upgrade guide](docs/updates/0.22.md)

* * *

## II. USING SHIPIT {#using-shipit}

The main workflows in Shipit are [adding stacks](#adding-stacks), [working on stacks](#working-on-stacks), and [configuring stacks](#configuring-stacks).

A **stack** is composed of a GitHub repository, a branch, and a deployment environment. Shipit tracks the commits made to the branch, and then displays them in the stack overview. From there, you can deploy the branch to whatever environment you've chosen (some typical environments include *production*, *staging*, *performance*, etc.).

### Add a new stack {#adding-stacks}

1. From the main page in Shipit, click **Add a stack**.
2. On the **Create a stack** page, enter the required information:
    * Repo
    * Branch
    * Environment
    * Deploy URL
3. When you're finished, click **Create stack**.

### Work on an existing stack {#working-on-stacks}

1. If you want to browse the list of available stacks, click **Show all stacks** on the main page in Shipit. If you know the name of the stack you're looking for, enter it in the search field.
2. Click the name of the stack you want to open.
3. From a stack's overview page, you can:
    * review previous deploys
    * deploy any undeployed commits by clicking **Deploy**
    * rollback to an earlier build by clicking **Rollback to this deploy**
    * adjust the stack's settings by clicking the gear icon in the page header
    * perform any custom tasks that are defined in the `shipit.yml` file
4. When you're ready to deploy an undeployed commit, click the relevant **Deploy** button on the stack's overview page.
5. From the **Deploy** page, complete the checklist, then click **Create deploy**.

### Edit stack settings {#configuring-stacks}

To edit a stack's settings, open the stack in Shipit, then click the gear icon in the page header.

From a stack's **Settings** page, you can:

* change the deploy URL
* enable and disable continuous deployment
* lock and unlock deploys through Shipit
* resynchronize the stack with GitHub
* delete the stack from Shipit

* * *

## III. REFERENCE {#reference}

### Configuring `shipit.yml` {#configuring-shipit}

The settings in the `shipit.yml` file relate to the different things you can do with Shipit:

* [Installing Dependencies](#installing-dependencies) (`dependencies`)
* [Deployment](#deployment) (`deploy`, `rollback`, `fetch`)
* [Environment](#environment) (`machine.environment`, `machine.directory`, `machine.cleanup`)
* [CI](#ci) (`ci.require`, `ci.hide`, `ci.allow_failures`)
* [Merge Queue](#merge-queue) (`merge.revalidate_after`, `merge.require`, `merge.ignore`, `merge.max_divergence`)
* [Custom Tasks](#custom-tasks) (`tasks`)
* [Custom links](#custom-links) (`links`)
* [Review Process](#review-process) (`review.checklist`, `review.monitoring`, `review.checks`)
* [Inherit From](#inherit-from)(`inherit_from`)

All the settings in `shipit.yml` are optional. Most applications can be deployed from Shipit without any configuration.

Also, if your repository is deployed different ways depending on the environment, you can have an alternative `shipit.yml` by including the environment name.

For example for a stack like: `my-org/my-repo/staging`, `shipit.staging.yml` will have priority over `shipit.yml`.

In order to reduce duplication across different environment specific files, you can specify an `inherit_from` key in your relevant `shipit.yml` file. This key expects a string of the file name to inherit from. If this key is specified, a deep-merge will be performed on the file therein, overwriting any duplicated values from the parent. See [Inherit From](#inherit-from)(`inherit_From`) for example.

Lastly, if you override the `app_name` configuration in your Shipit deployment, `yourapp.yml` and `yourapp.staging.yml` will work.

* * *

### Respecting bare `shipit.yml` files {#respecting-bare-files}

Shipit will, by default, respect the "bare" `shipit.yml` file as a fallback option if no more specifically-named file exists (such as `shipit.staging.yml`).

You can configure this behaviour via the attribute `Shipit.respect_bare_shipit_file`.

* The value `false` will disable this behaviour and instead cause Shipit to emit an error upon deploy if Shipit cannot find a more specifically-named file.
* Setting this attribute to any other value (**including `nil`**), or not setting this attribute, will cause Shipit to use the default behaviour of respecting bare `shipit.yml` files.

You can determine if Shipit is configured to respect bare files using `Shipit.respect_bare_shipit_file?`.

* * *

### Installing dependencies

The **`dependencies`** step allows you to install all the packages your deploy script needs.

#### Bundler {#bundler-support}

If your application uses Bundler, Shipit will detect it automatically and take care of the `bundle install` and prefix your commands with `bundle exec`.

By default, the following gem groups will be ignored:

  * `default`
  * `production`
  * `development`
  * `test`
  * `staging`
  * `benchmark`
  * `debug`

The gems you need in order to deploy should be in a different group, such as `deploy`.

For example:

```yml
dependencies:
  bundler:
    without:
      - development
      - test
      - debug
```

#### Other dependencies

If your deploy script uses another tool to install dependencies, you can install them manually via `dependencies.override`:

```yml
dependencies:
  override:
    - npm install
```


**`dependencies.pre`** If you wish to execute commands before Shipit installs the dependencies, you can specify them here.

For example:

```yml
dependencies:
  pre:
    - mkdir tmp/
    - cp -R /var/cache/ tmp/cache
```


**`dependencies.bundler.frozen`** If you wish to execute your bundle, for the **deploy** group, without the frozen flag:

For example:

```yml
dependencies:
  bundler:
    frozen: false
```


**`dependencies.post`** If you wish to execute commands after Shipit installed the dependencies, you can specify them here:

For example:

```yml
dependencies:
  post:
    - cp -R tmp/cache /var/cache/
```

### Deployment

The `deploy` and `rollback` sections are the core of Shipit:

**`deploy.override`** contains an array of the shell commands required to deploy the application. Shipit will try to infer it from the repository structure, but you can change the default inference.

For example:

```yml
deploy:
  override:
    - ./script/deploy
```


**`deploy.pre`** If you wish to execute commands before Shipit executes your deploy script, you can specify them here.

For example:

```yml
deploy:
  pre:
    - ./script/notify_deploy_start
```


**`deploy.post`** If you wish to execute commands after Shipit executed your deploy script, you can specify them here.

For example:

```yml
deploy:
  post:
    - ./script/notify_deploy_end
```


If you would like the post script to run even on error, you can pass the following option:

```yml
deploy:
  post:
    - ./script/notify_deploy_end: { on_error: true }
```

Or

```yml
deploy:
  post:
    - ./script/notify_deploy_end:
        on_error: true
```

This option can come in handy when you are tracking deployment externally. The default behaviour will not run the post script.


You can also accept custom environment variables defined by the user that triggers the deploy:

**`deploy.variables`** contains an array of variable definitions.

For example:

```yaml
deploy:
  variables:
    -
      name: RUN_MIGRATIONS
      title: Run database migrations on deploy
      default: 1
```


**`deploy.variables.select`** will turn the input into a `<select>` of values.

For example:

```yaml
deploy:
  variables:
    -
      name: REGION
      title: Run a deploy in a given region
      select:
        - east
        - west
        - north
```


**`deploy.max_commits`** defines the maximum number of commits that should be shipped per deploy. Defaults to `8` if no value is provided.

To disable this limit, you can use an explicit null value: `max_commits: null`. Continuous Delivery will then deploy any number of commits.

Human users will be warned that they are not respecting the recommendation, but allowed to continue.
However, continuous delivery will respect this limit. If there is no deployable commits in this range, a human intervention will be required.

For example:

```yaml
deploy:
  max_commits: 5
```


**`deploy.interval`** defines the interval between the end of a deploy and the next deploy, when continuous delivery is enabled. You can use s, m, h, d as units for seconds, minutes, hours, and days. Defaults to 0, which means a new deploy will start as soon as the current one finishes.

For example, this will wait 5 minutes after the end of a deploy before starting a new one:

```yaml
deploy:
  interval: 5m
```


**`deploy.retries`** enables retries for a stack, and defines the maximum amount of times that Shipit will retry a deploy that finished with a `failed`, `error` or `timedout` status.

For example, this will retry a deploy twice if it fails.

```yaml
deploy:
  retries: 2
```


**`rollback.override`** contains an array of the shell commands required to rollback the application to a previous state. Shipit will try to infer it from the repository structure, but you can change the default inference. This key defaults to `disabled` unless Capistrano is detected.

For example:

```yml
rollback:
  override:
    - ./script/rollback
```


**`rollback.pre`** If you wish to execute commands before Shipit executes your rollback script, you can specify them here:

For example:

```yml
rollback:
  pre:
    - ./script/notify_rollback_start
```


**`rollback.post`** If you wish to execute commands after Shipit executed your rollback script, you can specify them here:

For example:

```yml
rollback:
  post:
    - ./script/notify_rollback_end
```


**`fetch`** contains an array of the shell commands that Shipit executes to check the revision of the currently-deployed version. This key defaults to `disabled`.

For example:
```yml
fetch:
  curl --silent https://app.example.com/services/ping/version
```

> [!NOTE]
> Currently, deployments in emergency mode are configured to occur concurrently via [the `build_deploy` method](https://github.com/Shopify/shipit-engine/blob/main/app/models/shipit/stack.rb),
> whose `allow_concurrency` keyword argument defaults to `force`, where `force` is true when emergency mode is enabled.
> If you'd like to separate these two from one another, override this method as desired in your service.

### Kubernetes

**`kubernetes`** allows to specify a Kubernetes namespace and context to deploy to.

For example:
```yml
kubernetes:
  namespace: my-app-production
  context: tier4
```

**`kubernetes.template_dir`** allows to specify a Kubernetes template directory. It defaults to `./config/deploy/$ENVIRONMENT`

### Environment

**`machine.environment`** contains the extra environment variables that you want to provide during task execution.

For example:
```yml
machine:
  environment:
    key: val # things added as environment variables
```

### Directory

**`machine.directory`** specifies a subfolder in which to execute all tasks. Useful for repositories containing multiple applications or if you don't want your deploy scripts to be located at the root.

For example:
```yml
machine:
  directory: scripts/deploy/
```

### Cleanup

**`machine.cleanup`** specifies whether or not the deploy working directory should be cleaned up once the deploy completed. Defaults to `true`, but can be useful to disable temporarily to investigate bugs.

For example:
```yml
machine:
  cleanup: false
```

### CI

**`ci.require`** contains an array of the [statuses context](https://docs.github.com/en/rest/reference/commits#commit-statuses) you want Shipit to disallow deploys if any of them is missing on the commit being deployed.

For example:
```yml
ci:
  require:
    - ci/circleci
```

**`ci.hide`** contains an array of the [statuses context](https://docs.github.com/en/rest/reference/commits#commit-statuses) you want Shipit to ignore.

For example:
```yml
ci:
  hide:
    - ci/circleci
```

**`ci.allow_failures`** contains an array of the [statuses context](https://docs.github.com/en/rest/reference/commits#commit-statuses) you want to be visible but not to required for deploy.

For example:
```yml
ci:
  allow_failures:
    - ci/circleci
```

**`ci.blocking`** contains an array of the [statuses context](https://docs.github.com/en/rest/reference/commits#commit-statuses) you want to disallow deploys if any of them is missing or failing on any of the commits being deployed.

For example:
```yml
ci:
  blocking:
    - soc/compliance
```

### Merge Queue

The merge queue allows developers to register pull requests which will be merged by Shipit once the stack is clear (no lock, no failing CI, no backlog). It can be enabled on a per-stack basis via the settings page.

It can be customized via several `shipit.yml` properties:

**`merge.revalidate_after`** a duration after which pull requests that couldn't be merged are rejected from the queue. Defaults to unlimited.

For example:
```yml
merge:
  revalidate_after: 12m30s
```

**`merge.require`** contains an array of the [statuses context](https://docs.github.com/en/rest/reference/commits#commit-statuses) that you want Shipit to consider as failing if they aren't present on the pull request. Defaults to `ci.require` if present, or empty otherwise.

For example:
```yml
merge:
  require:
    - continuous-integration/travis-ci/push
```

**`merge.ignore`** contains an array of the [statuses context](https://docs.github.com/en/rest/reference/commits#commit-statuses) that you want Shipit not to consider when merging pull requests. Defaults to the union of `ci.allow_failures` and `ci.hide` if any is present or empty otherwise.

For example:
```yml
merge:
  ignore:
    - codeclimate
```

**`merge.method`** the [merge method](https://docs.github.com/en/rest/reference/pulls#merge-a-pull-request--parameters) to use for this stack. If it's not set the default merge method will be used. Can be either `merge`, `squash` or `rebase`.

For example:
```yml
merge:
  method: squash
```

**`merge.max_divergence.commits`** the maximum number of commits a pull request can be behind it's merge base, after which pull requests are rejected from the merge queue.

For example:
```yml
merge:
  max_divergence:
    commits: 50
```

**`merge.max_divergence.age`** a duration after the commit date of the merge base, after which pull requests will be rejected from the merge queue.

For example:
```yml
merge:
  max_divergence:
    age: 72h
```

### Custom tasks

You can create custom tasks that users execute directly from a stack's overview page in Shipit. To create a new custom task, specify its parameters in the `tasks` section of the `shipit.yml` file. For example:

**`tasks.restart`** restarts the application.

```yml
tasks:
  restart:
    action: "Restart Application"
    description: "Sometimes needed if you want the application to restart but don't want to ship any new code."
    steps:
      - ssh deploy@myserver.example.com 'touch myapp/restart.txt'
```

By default, custom tasks are not allowed to be triggered while a deploy is running. But if it's safe for that specific task, you can change that behaviour with the `allow_concurrency` attribute:

```yml
tasks:
  flush_cache:
    action: "Flush Cache"
    steps:
      - ssh deploy@myserver.example.com 'myapp/flush_cache.sh'
    allow_concurrency: true
```

Tasks like deploys can prompt for user defined environment variables:

```yml
tasks:
  restart:
    action: "Restart Application"
    description: "Sometimes needed if you want the application to restart but don't want to ship any new code."
    steps:
      - ssh deploy@myserver.example.com 'touch myapp/restart.txt'
    variables:
      -
        name: FORCE
        title: Restart server without waiting for in-flight requests to complete (Dangerous).
        default: 0
```

You can also make these variables appear in the task title:

```yml
tasks:
  failover:
    action: "Failover a pod"
    title: "Failover Pod %{POD_ID}"
    steps:
      - script/failover $POD_ID
    variables:
      - name: POD_ID
```

### Custom Links

You can add custom links to the header of a stacks overview page in Shipit. To create a new custom link, specify its parameters in the `links` section of the shipit.yml file. The link title is a humanized version of the key. For example:

**`links.monitoring_dashboard`** creates a link in the header of the page titled "Monitoring dashboard"

You can specify multiple custom links:

```yml
links:
  monitoring_dashboard: https://example.com/monitoring.html
  other_link: https://example.com/something_else.html
```

### Review process

You can display review elements, such as monitoring data or a pre-deployment checklist, on the deployment page in Shipit:

**`review.checklist`** contains a pre-deploy checklist that appears on the deployment page in Shipit, with each item in the checklist as a separate string in the array. It can contain `strong` and `a` HTML tags. Users cannot deploy from Shipit until they have checked each item in the checklist.

For example:

```yml
review:
  checklist:
    - >
      Do you know if it is safe to revert the code being shipped? What happens if we need to undo this deploy?
    - Has the Docs team been notified of any major changes to the app?
    - Is the app stable right now?
```

**`review.monitoring`** contains a list of inclusions that appear on the deployment page in Shipit. Inclusions can either be images or iframes.

For example:

```yml
review:
  monitoring:
    - image: https://example.com/monitoring.png
    - iframe: https://example.com/monitoring.html
```

**`review.checks`** contains a list of commands that will be executed during the pre-deploy review step.
Their output appears on the deployment page in Shipit, and if continuous delivery is enabled, deploys will only be triggered if those commands are successful.

For example:

```yml
review:
  checks:
    - bundle exec rake db:migrate:status
```

### Inherit From

If the `inherit_from` key is specified, a deep-merge will be performed on the file therein, overwriting any duplicated values from the parent. Keys may be chained across files. Example:

``` yaml
# shipit.production.yml
inherit_from: shipit.staging.yml

machine:
  environment:
    PUBLIC: true
```

``` yaml
# shipit.staging.yml
inherit_from: shipit.yml

deploy:
  override:
    - ./some_deployment_process.sh ${PUBLIC}
```

``` yaml
# shipit.yml

machine:
  environment:
    TEST: true
    PUBLIC: false
```

Loading `shipit.production.yml` would result in:
```rb
{"machine"=>{"environment"=>{"TEST"=>true, "PUBLIC"=>true}}, "deploy"=>{"override"=>["./some_deployment_process.sh ${PUBLIC}"]}}
```

### Shell commands timeout

All the shell commands can take an optional `timeout` parameter. This is the value in seconds that a command can be inactive before Shipit will terminate the task.

```yml
deploy:
  override:
    - ./script/deploy:
        timeout: 30
  post:
    - ./script/notify_deploy_end: { timeout: 15 }
review:
  checks:
    - bundle exec rake db:migrate:status:
        timeout: 60
```

See also `commands_inactivity_timeout` in `secrets.yml` for a global timeout setting.


***

## Script parameters

Your deploy scripts have access to the following environment variables:

* `SHIPIT`: Set to `1` to allow your script to know it's executed by Shipit
* `SHIPIT_LINK`: URL to the task output, useful to broadcast it in an IRC channel
* `SHIPIT_USER`: Full name of the user that triggered the deploy/task
* `GITHUB_REPO_NAME`: Name of the GitHub repository being used for the current deploy/task.
* `GITHUB_REPO_OWNER`: The GitHub username of the repository owner for the current deploy/task.
* `EMAIL`: Email of the user that triggered the deploy/task (if available)
* `ENVIRONMENT`: The stack environment (e.g. `production` / `staging`)
* `BRANCH`: The stack branch (e.g. `main`)
* `LAST_DEPLOYED_SHA`: The git SHA of the last deployed commit
* `DIFF_LINK`: URL to the diff on GitHub.
* `TASK_ID`: ID of the task that is running
* All the content of the `secrets.yml` `env` key
* All the content of the `shipit.yml` `machine.environment` key

These variables are accessible only during deploys and rollback:

* `REVISION`: the git SHA of the revision that must be deployed in production
* `SHA`: alias for REVISION
* `FAILED`: Set to `1` or `0` to show the state of the task
* `ERROR_MESSAGE`: Contains the error when a deploy/rollback fails

The following is available when a rollback is triggered:

* `ROLLBACK`: set to `1`

## Configuring providers

### Heroku

To use Heroku integration (`lib/snippets/push-to-heroku`), make sure that the environment has [Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli) available.

### Kubernetes {#configuring-kubernetes}

For Kubernetes, you have to provision Shipit environment with the following tools:

* `kubectl`
* `kubernetes-deploy` [gem](https://github.com/Shopify/kubernetes-deploy)

## IV. INTEGRATING {#integrating}

### Registering webhooks {#integrating-webhooks}

Shipit handles several webhook types by default, listed in `Shipit::Wehbooks::DEFAULT_HANDLERS`, in order to implement default behaviours. Extra handler blocks can be registered via `Shipit::Webhooks.register_handler`. Valid handlers need only implement the `call` method - meaning any object which implements `call` - blocks, procs, or lambdas are valid. The webhooks controller will pass a `params` argument to the handler. Some examples:


#### Registering a Plain old Ruby Object as a handler

```ruby
class PullRequestHandler
  def call(params)
    # do something with pull request webhook events
  end
end

Shipit::Webhooks.register_handler('pull_request', PullRequestHandler)
```

#### Registering a Block as a handler

```ruby
Shipit::Webhooks.register_handler('pull_request') do |params|
  # do something with pull request webhook events
end
```

Multiple handler blocks can be registered. If any raise errors, execution will be halted and the request will be reported failed to GitHub.

## V. CONTRIBUTING {#contributing}

### Instructions {#contributing-instructions}

1. [Fork it](https://github.com/shopify/shipit-engine/fork)
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

### Local development {#contributing-local-dev}

This repository has a [test/dummy](/test/dummy) app in it which can be used for local development without having to set up a new Rails application.

Run `./bin/bootstrap` in order to bootstrap the dummy application. The bootstrap script is going to:

* Copy `config/secrets.development.example.yml` to `config/secrets.development.yml`;
* Make sure all dependencies are installed;
* Create and seed database (recreate database if already available);

Run `./test/dummy/bin/rails server` to run the rails dummy application.

Set the environment variable `SHIPIT_DISABLE_AUTH=1` in order to disable authentication.

If you need to test caching behaviour in the dummy application, use `bin/rails dev:cache`.
