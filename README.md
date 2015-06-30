# Shipit - Documentation
[![Build Status](https://travis-ci.org/Shopify/shipit-engine.svg?branch=master)](https://travis-ci.org/Shopify/shipit-engine)
[![Gem Version](https://badge.fury.io/rb/shipit-engine.svg)](http://badge.fury.io/rb/shipit-engine)

**Shipit** is a deployment tool that makes shipping code better for everyone. It's especially great for large teams of developers and designers who work together to build and deploy GitHub repos. You can use it to:

* add new applications to your deployment environment without having to change core configuration files repeatedly &mdash; `shipit.yml` is basically plug and play
* control the pace of development by pushing, locking, and rolling back deploys from within Shipit
* enforce checklists and provide monitoring right at the point of deployment.

Shipit's compatible with just about anything that you can deploy using a script. It natively detects stacks using [bundler](http://bundler.io/) and [Capistrano](http://capistranorb.com/), and it has tools that make it easy to deploy to [Heroku](https://www.heroku.com/) or [RubyGems](https://rubygems.org/). At Shopify, we've used Shipit to sychronize and deploy hundreds of projects across dozens of teams, using Python, Rails, RubyGems, Java, and Go.

This guide aims to help you [set up](#installation-and-setup), [use](#using-shipit), and [understand](#reference) Shipit.

*Shipit requires a database (MySQL, PostgreSQL or SQLite3), redis, and Ruby 2.1 or superior.*

* * *
<h2 id="toc">Table of contents</h2>
**I. INSTALLATION & SETUP**

* [Installation](#installation)
* [Configuring shipit.yml and secrets.yml](#configuring-ymls)

**II. USING SHIPIT**

* [Adding stacks](#adding-stacks)
* [Working on stacks](#working-on-stacks),
* [Configuring stacks](#configuring-stacks).

**III. REFERENCE**

* [Format and content of shipit.yml](#configuring-shipit)
* [Format and content of secrets.yml](#configuring-secrets)
* [Script parameters](#script-parameters)
* [Free samples](#sample-file)

* * *

<h2 id="installation-and-setup">I. INSTALLATION & SETUP</h2>

<h3 id="installation">Installation</h3>

*Shipit requires a database (MySQL, PostgreSQL or SQLite3), redis, and Ruby 2.1 or superior.*

Shipit provides you with a Rails template. To bootstrap your Shipit installation:

1. If you don't have Rails installed, run this command: `gem install rails`
2. Run this command:  `rails new shipit -m https://raw.githubusercontent.com/Shopify/shipit-engine/master/template.rb`
3. Enter your **Client ID**, **Client Secret**, and **GitHub API access token** when prompted. These can be found on your application's GitHub page.

<h3 id="configuring-ymls">Configuring <code>shipit.yml</code> and <code>secrets.yml</code></h3>

Shipit should just work right out of the box &mdash; you probably won't need to alter its configuration files before getting it up and running. But if you want to customize Shipit for your own deployment environment, you'll need to edit the `shipit.yml` and `secrets.yml` files:

* The settings in the `shipit.yml` file are related to the different things you can do within Shipit, such as handling deploys, performing custom tasks, and enforcing deployment checklists. If you want to edit these settings, [start here](#configuring-shipit).
* The settings in the `secrets.yml` file are related to the ways that Shipit connects with GitHub. If you want to edit these settings, [start here](#configuring-secrets).


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
    * perform any custom tasks that are defined in the `shipit.yml` file.
4. When you're ready to deploy an undeployed commit, click the relevant **Deploy** button on the stack's overview page.
5. From the **Deploy** page, complete the checklist, then click **Create deploy**.



<h3 id="configuring-stacks">Edit stack settings</h3>

To edit a stack's settings, open the stack in Shipit, then click the gear icon in the page header.

From a stack's **Settings** page, you can:

* change the deploy URL
* enable and disable continuous deployment
* lock and unlock deploys through Shipit
* resychronize the stack with GitHub
* delete the stack from Shipit.

* * *

<h2 id="reference">III. REFERENCE</h3>

<h3 id="configuring-shipit">Configuring <code>shipit.yml</code></h2>

The settings in the `shipit.yml` file relate to the different things you can do with Shipit:

* [Installing dependencies](#installing-dependencies) (`dependencies`)
* [Deployment](#deployment) (`deploy`, `rollback`, `fetch`)
* [Environment](#environment) (`machine.environment`)
* [Custom tasks](#custom-tasks) (`restart`, `unlock`)
* [Review Process](#review-process) (`monitor`, `checklist`, `checks`)

All the settings in `shipit.yml` are optional. Most applications can be deployed from Shipit without any configuration.

* * *

<h3 id="installing-dependencies">Installing dependencies</h3>

The **<code>dependencies</code>** step allows you to install all the packages your deploy script needs.

<h4 id="bundler-support">Bundler</h3>

If your application uses Bundler, Shipit will detect it automatically and take care of the `bundle install` and prefix your commands with `bundle exec`.

By default the following gem groups will be ignored:

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

<h4 id="other-dependencies">Other dependencies</h3>

If your deploy script uses another tool to install dependencies, you can install them manually via `dependencies.override`:

```yml
dependencies:
  override:
    - npm install
```

<h3 id="deployment">Deployment</h3>

The `override` and `deployment` deployment tasks are the core of Shipit:

**<code>deploy.override</code>** contains an array of the shell commands required to deploy the application. Shipit will try to infer it from the repository structure, but you can change the default inference.

For example:

```yml
deploy:
  override:
    - ./script/deploy
```
<br>

**<code>rollback.override</code>** contains an array of the shell commands required to rollback the application to a previous state. Shipit will try to infer it from the repository structure, but you can change the default inference. This key defaults to disabled unless Capistrano is detected.

For example:

```yml
rollback:
  override:
    - ./script/rollback
```
<br>

**<code>fetch</code>** contains an array of the shell commands that Shipit executes to check the revision of the currently-deployed version. This key defaults to disabled.

For example:
```yml
fetch:
  curl --silent https://app.example.com/services/ping/version
```
<h3 id="environment">Environment</h3>

**<code>machine.environment</code>** contains the extra environment variables that you want to provide during task execution.

For example:
```yml
key: val # things added as environment variables
```


<h3 id="custom-tasks">Custom tasks</h3>

You can create custom tasks that users execute directly from a stack's overview page in Shipit. To create a new custom task, specify its parameters in the `tasks` section of the `shipit.yml` file. For example:

**<code>tasks</code>** restarts the application.

```yml
tasks:
  restart:
    action: "Restart Application"
    description: "Sometimes needed if you the application to restart but don't want to ship any new code."
    steps:
      - ssh deploy@myserver.example.com 'touch myapp/restart.txt'
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
Their output appears on the deployment page in Shipit.

For example:

```yml
review:
  checks:
    - bundle exec rake db:migrate:status
```

***
<h2 id="configuring-secrets">Configuring <code>secrets.yml</code></h2>

The settings in the `secrets.yml` file relate to the ways that GitHub connects with Shipit:

**`secret_key_base`** is used to verify the integrity of signed cookies.

For example:

```yml
development:
  secret_key_base: s3cr3t # This needs to be a very long, fully random
```
<br>

**`github_oauth`** contains the settings required to authenticate users through GitHub.

The value for `id` is your application's  *Client ID*, and the value for `secret` is your application's *Client Secret* &mdash; both of these should appear on your application's GitHub page.

The `team` is optional, and required only if you want to specify a team that has access to the stack in Shipit.

For example:

```yml
development:
  github_oauth:
    id: (your application's Client ID)
    secret: (your application's Client Secret)
    team: Shipit/team
```
<br>

**`github_api`** communicates with the GitHub API about the stacks and setup Hooks. It should reflect the guidelines at  https://github.com/octokit/octokit.rb.

If you specify an `access_token`, you don't need a `login` and `password`. The opposite is also true:  if you specify a `login` and `password`, then you don't need an `access_token`.

For example:

```yml
development:
  github_api:
    access_token: 10da65c687f6degaf5475ce12a980d5vd8c44d2a
```
<br>

**`host`**  is the host that hosts Shipit. It's used to generate URLs, and it's the host that GitHub will try to talk to.

For example:
```yml
development:
  host: 'http://localhost:3000'
```
<br>

**`redis_url`** is the URL of the redis instance that Shipit uses.

For example:

```yml
development:
  redis_url: "redis://127.0.0.1:6379/7"
```

<br>

If you use GitHub Enterprise, you must also specify the `github_domain`.

For example:
```yml
development:
  github_domain: "github.example.com"

```

<h2 id="script-parameters">Script parameters</h2>

Your deploy scripts have access to the following environment variables:

* `SHIPIT`: Set to "1" allow your script to know it's executed by Shipit
* `SHIPIT_LINK`: URL to the task output, usefull to broadcast it in an IRC channel
* `USER`: Full name of the user that triggered the deploy/task
* `EMAIL`: Email of the user that triggered the deploy/task (if available)
* `ENVIRONMENT`: The stack environment (e.g production / staging)
* `LAST_DEPLOYED_SHA`: The git SHA of the last deployed commit
* All the content of the `secrets.yml` `env` key
* All the content of the `shipit.yml` `machine.environment` key

These variables are accessible only during deploys and rollback:

* `REVISION`: the git SHA of the revision that must be deployed in production
* `SHA`: alias for REVISION
