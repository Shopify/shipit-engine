# Shipit setup guide

## Forewords

At this point Shipit is mostly a Rails engine, so setting it up in production requires some Rails development knowledge.

Deploying and hosting a Rails application is not trivial, and this document assumes you know how to do it.

In the future we'd like to provide it fully packaged inside a Docker container, but it hasn't been done yet.

## Creating the Rails app

*Shipit requires a database (MySQL, PostgreSQL or SQLite3), Redis, and Ruby 2.6 or superior.*

Shipit provides you with a Rails template. To bootstrap your Shipit installation:

1. If you don't have Rails installed, run this command: `gem install rails -v 7.1`
2. Run this command:  `rails _7.1_ new shipit --skip-action-cable --skip-turbolinks --skip-action-mailer --skip-active-storage --skip-webpack-install --skip-action-mailbox --skip-action-text -m https://raw.githubusercontent.com/Shopify/shipit-engine/main/template.rb`

## Creating the GitHub App

Shipit needs a GitHub App to authenticate users, receive Webhooks and access the API.

You can create a new one for your organization at `https://github.com/organizations/<your-org>/settings/apps/new`, or [https://github.com/settings/apps/new](https://github.com/settings/apps/new) for a regular user.

  - Homepage URL: The URL where Shipit will be deployed, e.g. `https://example.com`.
  - User authorization callback URL: It must be set to `<homepage>/github/auth/github/callback`, e.g. `https://example.com/github/auth/github/callback`.
  - Setup URL: Leave it empty.
  - Webhook URL: It must be set to `<homepage>/webhooks`, e.g. `https://example.com/webhooks`.
  - Webhook secret (optional): Fill it with some randomly generated string, and *keep it in clear on the side, you'll need it later*.
  - Repository permissions:
    - Checks: Read & write
    - Commit statuses: Read-only
    - Contents: Read & write (to allow merging)
    - Deployments: Read & write
    - Issues: Read & write (to allow closing related issues on merge)
    - Metadata: Read-only
    - Pull requests: Read & write

  - Organization permissions:
    - Members: Read-only
    
  - Events:
    - Check run
    - Check suite
    - Membership
    - Pull request
    - Push
    - Status


## Installing the GitHub App on your organization

Once it's created, make sure it's installed on your organization via the `Install App` menu on the side.

## Updating the config/secrets.yml

The `config/secrets.yml` file will hold your secrets, by default it is ignored by git, so it's up to you to decide how secrets are deployed in production, as Rails doesn't enforce any method.

It should look like this:

```yaml
production:
  secret_key_base: some-long-string
  host: example.com
  redis_url: "redis://redis-host"
  github:
    app_id: 42
    installation_id: 43
    bot_login: "my-app[bot]"
    webhook_secret: some-secret-value
    private_key: |
      -----BEGIN RSA PRIVATE KEY-----
      MIIEpAIBAAKCAQEA7iUQC2uUq/gtQg0gxtyaccuicYgmq1LUr1mOWbmwM1Cv63+S
      73qo8h87FX+YyclY5fZF6SMXIys02JOkImGgbnvEOLcHnImCYrWs03msOzEIO/pG
      M0YedAPtQ2MEiLIu4y8htosVxeqfEOPiq9kQgFxNKyETzjdIA9q1md8sofuJUmPv
      ibacW1PecuAMnn+P8qf0XIDp7uh6noB751KvhCaCNTAPtVE9NZ18OmNG9GOyX/pu
      pQHIrPgTpTG6KlAe3r6LWvemzwsMtuRGU+K+KhK9dFIlSE+v9rA32KScO8efOh6s
      Gu3rWorV4iDu14U62rzEfdzzc63YL94sUbZxbwIDAQABAoIBADLJ8r8MxZtbhYN1
      u0zOFZ45WL6v09dsBfITvnlCUeLPzYUDIzoxxcBFittN6C744x3ARS6wjimw+EdM
      TZALlCSb/sA9wMDQzt7wchhz9Zh2H5RzDu+2f54sjDh38KqancdT8PO2fAFGxX/b
      qicOVyeZB9gv6MJtJc20olBbuXAeBNfcDABF9oxF+0i+Ssg7B4VXiqgcjtGbr/Og
      qRll7AqyTArVx2xEcVfZxeZ4zGnigzcJq4te7yYpxzwk+RxblkPh54Yt4WxZ+8DI
      Rsn3r6ajlpwzpwvsJFU2Txq7xBTzGQMFmy/Pnjk83kP2cogxB2+tRyjITGqTwD8b
      gg9PFCkCgYEA+7u8A0l0Cz6p0SI6c7ftVePVRiIhpawWN7og/wEmI6zUjm/3rA+R
      hrhaVKuOD8QF/HdDsqTck5gjGAjTmJz6r33/cl1Tz+pr62znsrB4r0yMKvQbKN81
      WGaWOsi2+ZXqLNv5h5wpUF0MTKlXHeKnwP5kuEvGwVn6WURFCh6PhLMCgYEA8i5e
      JjulJVGyd5HuoY3xyO7E6DjidsqRnVRq+hYpORjnHvTmSwe4+tH4ha2p9Kv2Y6k3
      C1NYY/fSMQoYCCRaYyJleI+la/9tsZqAmtms4ZB8KhFmPHf9fW75i6G0xKWyZ8K+
      E2Ft/UaEiM282593cguV6+Kt5uExnyPxLLK4FlUCgYEAwRJ/JGI8/7bjFkTTYheq
      j5q75BufhOrU6471acAe2XPgXxLfefdC3Xodxh0CS3NESBvNL4Ikr4sbN37lk4Kq
      /th7iOKtuqUIeru/hZy2I3VpeDRbdGCmEJQ2GwYA2LKztg5Nd0Y9paaIHXAwIfrK
      QUqcQ4HTAk8ZpUeoUBeaaeMCgYANLmbjb9WiPVsYVPIHCwHA7PX8qbPxwT7BsGmO
      KQyfVfKmZa/vH4F67Vi4deZNMdrcO8aKMEQcVM2065a5QrlEsgeR00eupB1lUEJ1
      qylUsZeAdqf43JMIc7TTW77KATa/nQLZbTEeWus1wvTngztuEqFbUGAks9cOkVc8
      FpIcbQKBgQDVIL8gPLmn0f+4oLF8MBC+oxtKpz14X5iJ1saGFkzW5I+nIEskpS0S
      qtirnTCnJFGdCrFwctnxiuiCmyGwpBYdjIfHyvYAHnqAtMnESzCUyeSFZiquVW5W
      MvbMmDPoV27XOHU9kIq6NXtfrkpufiyo6/VEYWozXalxKLNuqLYfPQ==
      -----END RSA PRIVATE KEY-----
    oauth:
      id: Iv1.bf2c2c45b449bfd9
      secret: ef694cd6e45223075d78d138ef014049052665f1
      teams:
    domain: # The domain name of your GitHub Enterprise instance, leave it empty if you use github.com
```

**`secret_key_base`** Should be generated automatically by Rails. It is used for signing session cookies etc.

**`host`** Should specify the domain of your shipit instance, e.g. `shipit.example.com`.

**`redis_url`** Should point to a working Redis database.

**`github.app_id`** The GitHub App ID, it can be found under General > About

**`github.installation_id`** The ID of your GitHub App installation, it can be found under Organization Settings > Installed GitHub Apps > Configure. Then look at the URL it should follow this pattern: `https://github.com/organizations/<you-org>/settings/installations/<app-id>`.

**`github.bot_login`** The login of the App [bot] user. Every GitHub App have an associated `[bot]` user which acts as the author of the App actions through the API, for example when an App merges a Pull Request. It should be the App "slug" with the suffix `[bot]`. For example if your app settings URL is `https://github.com/organizations/ACME/settings/apps/acme-shipit/installations`, the bot user should be `acme-shipit[bot]`. If you are unsure, you can leave it empty.

**`github.webhook_secret`** If you've set a webhook secret during the App creating, you should copy it here.

**`github.private_key`** In your GitHub App settings, on the `General` section, you can generate and download a private key. You will end up with a `.pem` file and you need to copy it's content here.

**`github.oauth.id`** and **`github.oauth.secret`** In your GitHub App settings, on the `General` section, you can find these two at the bottom of the page.

**`github.oauth.teams`** optional, required only if you want to restrict access to a set of GitHub teams.

If it's missing, the Shipit installation will be public unless you setup another authentication method.

After you change the list of teams, you have to invoke `bin/rake teams:fetch` to prefetch the team members.

For example:

```yml
production:
  github:
    oauth:
      id: (your application's Client ID)
      secret: (your application's Client Secret)
      teams:
        - Shipit/team
        - Shipit/another_team
```

**`commands_inactivity_timeout`** is the duration after which Shipit will terminate a command if no ouput was received. Default is `300` (5 minutes).

For example:
```yml
production:
  commands_inactivity_timeout: 900 # 15 minutes
```

**`default_merge_method`** is the merge method used by the merge queue unless specified otherwise in the stack's `shipit.yml`. Can be either `merge`, `rebase`, or `squash`. If not set it will default to `merge`.

For example:
```yml
production:
  default_merge_method: squash
```

**`update_latest_deployed_ref`** can be set to true to have a shipit maintain a git branch pointing to the last deployed commit.

```yml
production:
  update_latest_deployed_ref: true
```

**`git_progress_output`** enables git commands verbosity in the deploys.

```yml
production:
  git_progress_output: true
```

### Using Multiple Github Applications

A Github application can only authenticate to the Github organization it's installed in. If you want to deploy code from multiple Github organizations the `github` section of your `config/secrets.yml` will need to be formatted differently. The top-level keys should be the name of each Github organization, and the following sub-keys are the Github app details for that particular organization.

For example:

```yml
production:
  github:
    somegithuborg:
      app_id:
      installation_id:
      webhook_secret:
      private_key:
      oauth:
        id:
        secret:
        teams:
    someothergithuborg:
      app_id:
      installation_id:
      webhook_secret:
      private_key:
      oauth:
        id:
        secret:
        teams:
```

## Running Cron

Shipit requires some periodic tasks to be executed to function properly. If you're running on Heroku, you can use the [Heroku Scheduler](https://devcenter.heroku.com/articles/scheduler) add on to run Shipit cron jobs, though it will only run at a maximum frequency of once every 10 minutes.

 - Run `bin/rake cron:minutely` as close to every minute as possible
 - Run `bin/rake cron:hourly` as close to every hour as possible
