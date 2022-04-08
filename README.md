# Shipit - Documentation
[![Build Status](https://travis-ci.org/Shopify/shipit-engine.svg?branch=master)](https://travis-ci.org/Shopify/shipit-engine)
[![Gem Version](https://badge.fury.io/rb/shipit-engine.svg)](http://badge.fury.io/rb/shipit-engine)

**Shipit** is a deployment tool that makes shipping code better for everyone. It's especially great for large teams of developers and designers who work together to build and deploy GitHub repos. You can use it to:

* add new applications to your deployment environment without having to change core configuration files repeatedly &mdash; `shipit.yml` is basically plug and play
* control the pace of development by pushing, locking, and rolling back deploys from within Shipit
* enforce checklists and provide monitoring right at the point of deployment.

Shipit is compatible with just about anything that you can deploy using a script. It natively detects stacks using [bundler](http://bundler.io/) and [Capistrano](http://capistranorb.com/), and it has tools that make it easy to deploy to [Heroku](https://www.heroku.com/) or [RubyGems](https://rubygems.org/). At Shopify, we've used Shipit to synchronize and deploy hundreds of projects across dozens of teams, using Python, Rails, RubyGems, Java, and Go.

This guide aims to help you [set up](#installation-and-setup), [use](#using-shipit), and [understand](#reference) Shipit.

*Shipit requires a database (MySQL, PostgreSQL or SQLite3), redis, and Ruby 2.6 or superior.*

* * *
<h2 id="toc">Table of contents</h2>

**I. INSTALLATION & SETUP**

* [Installation](#installation)
* [Updating an existing installation](#updating-shipit)

**II. USING SHIPIT**

* [Adding stacks](#adding-stacks)
* [Working on stacks](#working-on-stacks),
* [Configuring stacks](#configuring-stacks).

**III. REFERENCE**

* [Format and content of shipit.yml](#configuring-shipit)
* [Script parameters](#script-parameters)
* [Configuring providers](#configuring-providers)
* [Free samples](/examples/shipit.yml)

**IV. INTEGRATING**

* [Registering webhooks](#integrating-webhooks)

**V. CONTRIBUTING**

* [Instructions](#contributing-instructions)
* [Local development](#contributing-local-dev)

* * *

<h2 id="installation-and-setup">I. INSTALLATION & SETUP</h2>

<h3 id="installation">Installation</h3>

To create a new Shipit installation you can follow the [setup guide](docs/setup.md).

<h3 id="updating-shipit">Updating an existing installation</h3>

1. If you locked the gem to a specific version in your Gemfile, update it there.
2. Update the `shipit-engine` gem with `bundle update shipit-engine`.
3. Install new migrations with `rake shipit:install:migrations db:migrate`.

<h3 id="special-update">Specific updates requiring more steps</h3>

If you are upgrading from `0.21` or older, you will have to update the configuration. Please follow [the dedicated upgrade guide](docs/updates/0.22.md)

* * *

<h2 id="using-shipit">II. USING SHIPIT</h2>

The main workflows in Shipit are [adding stacks](#adding-stacks), [working on stacks](#working-on-stacks), and [configuring stacks](#configuring-stacks).

A **stack** is composed of a GitHub repository, a branch, and a deployment environment. Shipit tracks the commits made to the branch, and then displays them in the stack overview. From there, you can deploy the branch to whatever environment you've chosen (some typical environments include *production*, *staging*, *performance*, etc.).

<h3 id="adding-stacks">Add a new stack</h3>

1. From the main page in Shipit, click **Add a stack**.
2. On the **Create a stack** page, enter the required information:
    * Repo
    * Branch
    * Environment
    * Deploy URL
3. When you're finished, click **Create stack**.

<h3 id="working-on-stacks">Work on an existing stack</h3>

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



<h3 id="configuring-stacks">Edit stack settings</h3>

To edit a stack's settings, open the stack in Shipit, then click the gear icon in the page header.

From a stack's **Settings** page, you can:

* change the deploy URL
* enable and disable continuous deployment
* lock and unlock deploys through Shipit
* resynchronize the stack with GitHub
* delete the stack from Shipit

* * *

<h2 id="reference">III. REFERENCE</h2>

<h3 id="configuring-shipit">Configuring <code>shipit.yml</code></h3>

The settings in the `shipit.yml` file relate to the different things you can do with Shipit:

* [Installing Dependencies](#installing-dependencies) (`dependencies`)
* [Deployment](#deployment) (`deploy`, `rollback`, `fetch`)
* [Environment](#environment) (`machine.environment`, `machine.directory`, `machine.cleanup`)
* [CI](#ci) (`ci.require`, `ci.hide`, `ci.allow_failures`)
* [Merge Queue](#merge-queue) (`merge.revalidate_after`, `merge.require`, `merge.ignore`, `merge.max_divergence`)
* [Custom Tasks](#custom-tasks) (`tasks`)
* [Custom links](#custom-links) (`links`)
* [Review Process](#review-process) (`review.checklist`, `review.monitoring`, `review.checks`)

All the settings in `shipit.yml` are optional. Most applications can be deployed from Shipit without any configuration.

Also, if your repository is deployed different ways depending on the environment, you can have an alternative `shipit.yml` by including the environment name.

For example for a stack like: `my-org/my-repo/staging`, `shipit.staging.yml` will have priority over `shipit.yml`.

Lastly, if you override the `app_name` configuration in your Shipit deployment, `yourapp.yml` and `yourapp.staging.yml` will work.

* * *

<h3 id="installing-dependencies">Installing dependencies</h3>

The **<code>dependencies</code>** step allows you to install all the packages your deploy script needs.

<h4 id="bundler-support">Bundler</h4>

If your application uses Bundler, Shipit will detect it automatically and take care of the `bundle install` and prefix your commands with `bundle exec`.

By default, the following gem groups will be ignored:

  - `default`
  - `production`
  - `development`
  - `test`
  - `staging`
  - `benchmark`
  - `debug`

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

<h4 id="other-dependencies">Other dependencies</h4>

If your deploy script uses another tool to install dependencies, you can install them manually via `dependencies.override`:

```yml
dependencies:
  override:
    - npm install
```

**<code>dependencies.pre</code>** If you wish to execute commands before Shipit installs the dependencies, you can specify them here.

For example:

```yml
dependencies:
  pre:
    - mkdir tmp/
    - cp -R /var/cache/ tmp/cache
```
<br>

**<code>dependencies.post</code>** If you wish to execute commands after Shipit installed the dependencies, you can specify them here:

For example:

```yml
dependencies:
  post:
    - cp -R tmp/cache /var/cache/
```
<br>


<h3 id="deployment">Deployment</h3>

The `deploy` and `rollback` sections are the core of Shipit:

**<code>deploy.override</code>** contains an array of the shell commands required to deploy the application. Shipit will try to infer it from the repository structure, but you can change the default inference.

For example:

```yml
deploy:
  override:
    - ./script/deploy
```
<br>

**<code>deploy.pre</code>** If you wish to execute commands before Shipit executes your deploy script, you can specify them here.

For example:

```yml
deploy:
  pre:
    - ./script/notify_deploy_start
```
<br>

**<code>deploy.post</code>** If you wish to execute commands after Shipit executed your deploy script, you can specify them here.

For example:

```yml
deploy:
  post:
    - ./script/notify_deploy_end
```
<br>


You can also accept custom environment variables defined by the user that triggers the deploy:

**<code>deploy.variables</code>** contains an array of variable definitions.

For example:

```yaml
deploy:
  variables:
    -
      name: RUN_MIGRATIONS
      title: Run database migrations on deploy
      default: 1
```
<br>

**<code>deploy.variables.select</code>** will turn the input into a `<select>` of values.

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
<br>

**<code>deploy.max_commits</code>** defines the maximum number of commits that should be shipped per deploy. Defaults to `8` if no value is provided.

To disable this limit, you can use use an explicit null value: `max_commits: null`. Continuous Delivery will then deploy any number of commits.

Human users will be warned that they are not respecting the recommendation, but allowed to continue.
However continuous delivery will respect this limit. If there is no deployable commits in this range, a human intervention will be required.

For example:

```yaml
deploy:
  max_commits: 5
```
<br>

**<code>deploy.interval</code>** defines the interval between the end of a deploy and the next deploy, when continuous delivery is enabled. You can use s, m, h, d as units for seconds, minutes, hours, and days. Defaults to 0, which means a new deploy will start as soon as the current one finishes.

For example, this will wait 5 minutes after the end of a deploy before starting a new one:

```yaml
deploy:
  interval: 5m
```

**<code>deploy.retries</code>** enables retries for a stack, and defines the maximum amount of times that Shipit will retry a deploy that finished with a `failed`, `error` or `timedout` status.

For example, this will retry a deploy twice if it fails.

```yaml
deploy:
  retries: 2
```

**<code>rollback.override</code>** contains an array of the shell commands required to rollback the application to a previous state. Shipit will try to infer it from the repository structure, but you can change the default inference. This key defaults to `disabled` unless Capistrano is detected.

For example:

```yml
rollback:
  override:
    - ./script/rollback
```
<br>

**<code>rollback.pre</code>** If you wish to execute commands before Shipit executes your rollback script, you can specify them here:

For example:

```yml
rollback:
  pre:
    - ./script/notify_rollback_start
```
<br>

**<code>rollback.post</code>** If you wish to execute commands after Shipit executed your rollback script, you can specify them here:

For example:

```yml
rollback:
  post:
    - ./script/notify_rollback_end
```
<br>


**<code>fetch</code>** contains an array of the shell commands that Shipit executes to check the revision of the currently-deployed version. This key defaults to `disabled`.

For example:
```yml
fetch:
  curl --silent https://app.example.com/services/ping/version
```
<h3 id="kubernetes">Kubernetes</h3>

**<code>kubernetes</code>** allows to specify a Kubernetes namespace and context to deploy to.

For example:
```yml
kubernetes:
  namespace: my-app-production
  context: tier4
```

**<code>kubernetes.template_dir</code>** allows to specify a Kubernetes template directory. It defaults to `./config/deploy/$ENVIRONMENT`

<h3 id="environment">Environment</h3>

**<code>machine.environment</code>** contains the extra environment variables that you want to provide during task execution.

For example:
```yml
machine:
  environment:
    key: val # things added as environment variables
```

<h3 id="directory">Directory</h3>

**<code>machine.directory</code>** specifies a subfolder in which to execute all tasks. Useful for repositories containing multiple applications or if you don't want your deploy scripts to be located at the root.

For example:
```yml
machine:
  directory: scripts/deploy/
```

<h3 id="cleanup">Cleanup</h3>

**<code>machine.cleanup</code>** specifies whether or not the deploy working directory should be cleaned up once the deploy completed. Defaults to `true`, but can be useful to disable temporarily to investigate bugs.

For example:
```yml
machine:
  cleanup: false
```

<h3 id="ci">CI</h3>

**<code>ci.require</code>** contains an array of the [statuses context](https://docs.github.com/en/rest/reference/commits#commit-statuses) you want Shipit to disallow deploys if any of them is missing on the commit being deployed.

For example:
```yml
ci:
  require:
    - ci/circleci
```

**<code>ci.hide</code>** contains an array of the [statuses context](https://docs.github.com/en/rest/reference/commits#commit-statuses) you want Shipit to ignore.

For example:
```yml
ci:
  hide:
    - ci/circleci
```

**<code>ci.allow_failures</code>** contains an array of the [statuses context](https://docs.github.com/en/rest/reference/commits#commit-statuses) you want to be visible but not to required for deploy.

For example:
```yml
ci:
  allow_failures:
    - ci/circleci
```

**<code>ci.blocking</code>** contains an array of the [statuses context](https://docs.github.com/en/rest/reference/commits#commit-statuses) you want to disallow deploys if any of them is missing or failing on any of the commits being deployed.

For example:
```yml
ci:
  blocking:
    - soc/compliance
```

<h3 id="merge-queue">Merge Queue</h3>

The merge queue allows developers to register pull requests which will be merged by Shipit once the stack is clear (no lock, no failing CI, no backlog). It can be enabled on a per stack basis via the settings page.

It can be customized via several `shipit.yml` properties:

**<code>merge.revalidate_after</code>** a duration after which pull requests that couldn't be merged are rejected from the queue. Defaults to unlimited.

For example:
```yml
merge:
  revalidate_after: 12m30s
```

**<code>merge.require</code>** contains an array of the [statuses context](https://docs.github.com/en/rest/reference/commits#commit-statuses) that you want Shipit to consider as failing if they aren't present on the pull request. Defaults to `ci.require` if present, or empty otherwise.

For example:
```yml
merge:
  require:
    - continuous-integration/travis-ci/push
```

**<code>merge.ignore</code>** contains an array of the [statuses context](https://docs.github.com/en/rest/reference/commits#commit-statuses) that you want Shipit not to consider when merging pull requests. Defaults to the union of `ci.allow_failures` and `ci.hide` if any is present or empty otherwise.

For example:
```yml
merge:
  ignore:
    - codeclimate
```

**<code>merge.method</code>** the [merge method](https://docs.github.com/en/rest/reference/pulls#merge-a-pull-request--parameters) to use for this stack. If it's not set the default merge method will be used. Can be either `merge`, `squash` or `rebase`.

For example:
```yml
merge:
  method: squash
```

**<code>merge.max_divergence.commits</code>** the maximum number of commits a pull request can be behind its merge base, after which pull requests are rejected from the merge queue.

For example:
```yml
merge:
  max_divergence:
    commits: 50
```

**<code>merge.max_divergence.age</code>** a duration after the commit date of the merge base, after which pull requests will be rejected from the merge queue.

For example:
```yml
merge:
  max_divergence:
    age: 72h
```

<h3 id="custom-tasks">Custom tasks</h3>

You can create custom tasks that users execute directly from a stack's overview page in Shipit. To create a new custom task, specify its parameters in the `tasks` section of the `shipit.yml` file. For example:

**<code>tasks.restart</code>** restarts the application.

```yml
tasks:
  restart:
    action: "Restart Application"
    description: "Sometimes needed if you want the application to restart but don't want to ship any new code."
    steps:
      - ssh deploy@myserver.example.com 'touch myapp/restart.txt'
```

By default, custom tasks are not allowed to be triggered while a deploy is running. But if it's safe for that specific task, you can change that behavior with the `allow_concurrency` attribute:

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

<h3 id="custom-links">Custom Links</h3>

You can add custom links to the header of a stacks overview page in Shipit. To create a new custom link, specify its parameters in the links section of the shipit.yml file. The link title is a humanized version of the key. For example:

**<code>links.monitoring_dashboard</code>** creates a link in the header of of the page titled "Monitoring dashboard"

You can specify multiple custom links:

```yml
links:
  monitoring_dashboard: https://example.com/monitoring.html
  other_link: https://example.com/something_else.html
```

<h3 id="review-process">Review process</h3>

You can display review elements, such as monitoring data or a pre-deployment checklist, on the deployment page in Shipit:

**<code>review.checklist</code>** contains a pre-deploy checklist that appears on the deployment page in Shipit, with each item in the checklist as a separate string in the array. It can contain `strong` and `a` HTML tags. Users cannot deploy from Shipit until they have checked each item in the checklist.

For example:

```yml
review:
  checklist:
    - >
      Do you know if it is safe to revert the code being shipped? What happens if we need to undo this deploy?
    - Has the Docs team been notified of any major changes to the app?
    - Is the app stable right now?
```
<br>

**<code>review.monitoring</code>** contains a list of inclusions that appear on the deployment page in Shipit. Inclusions can either be images or iframes.

For example:

```yml
review:
  monitoring:
    - image: https://example.com/monitoring.png
    - iframe: https://example.com/monitoring.html
```

<br>

**<code>review.checks</code>** contains a list of commands that will be executed during the pre-deploy review step.
Their output appears on the deployment page in Shipit, and if continuous delivery is enabled, deploys will only be triggered if those commands are successful.

For example:

```yml
review:
  checks:
    - bundle exec rake db:migrate:status
```

<h3 id="shell-commands-timeout">Shell commands timeout</h3>

All the shell commands can take an optional `timeout` parameter to limit their duration:

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

<h2 id="script-parameters">Script parameters</h2>

Your deploy scripts have access to the following environment variables:

* `SHIPIT`: Set to `1` to allow your script to know it's executed by Shipit
* `SHIPIT_LINK`: URL to the task output, useful to broadcast it in an IRC channel
* `SHIPIT_USER`: Full name of the user that triggered the deploy/task
* `GITHUB_REPO_NAME`: Name of the GitHub repository being used for the current deploy/task.
* `GITHUB_REPO_OWNER`: The GitHub username of the repository owner for the current deploy/task.
* `EMAIL`: Email of the user that triggered the deploy/task (if available)
* `ENVIRONMENT`: The stack environment (e.g `production` / `staging`)
* `BRANCH`: The stack branch (e.g `master`)
* `LAST_DEPLOYED_SHA`: The git SHA of the last deployed commit
* `DIFF_LINK`: URL to the diff on GitHub.
* `TASK_ID`: ID of the task that is running
* All the content of the `secrets.yml` `env` key
* All the content of the `shipit.yml` `machine.environment` key

These variables are accessible only during deploys and rollback:

* `REVISION`: the git SHA of the revision that must be deployed in production
* `SHA`: alias for REVISION

<h2 id="configuring-providers">Configuring providers</h2>

### Heroku

To use Heroku integration (`lib/snippets/push-to-heroku`), make sure that the environment has [Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli) available.

### Kubernetes

For Kubernetes, you have to provision Shipit environment with the following tools:

* `kubectl`
* `kubernetes-deploy` [gem](https://github.com/Shopify/kubernetes-deploy)

<h2 id="integrating">IV. INTEGRATING</h2>

<h3 id="integrating-webhooks">Registering webhooks</h3>

Shipit handles several webhook types by default, listed in `Shipit::Wehbooks::DEFAULT_HANDLERS`, in order to implement default behaviours. Extra handler blocks can be registered via `Shipit::Webhooks.register_handler`. Valid handlers need only implement the `call` method - meaning any object which implements `call` - blocks, procs, or lambdas are valid. The webhooks controller will pass a `params` argument to the handler. Some examples:


<h4>Registering a Plain old Ruby Object as a handler</h4>

```ruby
class PullRequestHandler
  def call(params)
    # do something with pull request webhook events
  end
end

Shipit::Webhooks.register_handler('pull_request', PullRequestHandler)
```

<h4>Registering a Block as a handler</h4>

```ruby
Shipit::Webhooks.register_handler('pull_request') do |params|
  # do something with pull request webhook events
end
```

Multiple handler blocks can be registered. If any raise errors, execution will be halted and the request will be reported failed to github.

<h2 id="contributing">V. CONTRIBUTING</h2>

<h3 id="contributing-instructions">Instructions</h3>

1. Fork it ( https://github.com/shopify/shipit-engine/fork )
1. Create your feature branch (git checkout -b my-new-feature)
1. Commit your changes (git commit -am 'Add some feature')
1. Push to the branch (git push origin my-new-feature)
1. Create a new Pull Request

<h3 id="contributing-local-dev">Local development</h3>

This repository has a [test/dummy](/test/dummy) app in it which can be used for local development without having to setup a new rails application.

Run `./bin/bootstrap` in order to bootstrap the dummy application. The bootstrap script is going to:

- Copy `config/secrets.development.example.yml` to `config/secrets.development.yml`;
- Make sure all dependencies are installed;
- Create and seed database (recreate database if already available);

Run `./test/dummy/bin/rails server` to run the rails dummy application.

Set the environment variable `SHIPIT_DISABLE_AUTH=1` in order to disable authentication.

If you need to test caching behaviour in the dummy application, use `bin/rails dev:cache`.
