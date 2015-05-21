# :shipit: Next

## Installation

```
gem 'shipit-engine'
```

```
bundle install
```


## Setup

```shell
$ git clone git@github.com:Shopify/shipit-engine.git
$ cd shipit-engine
$ script/bootstrap
```

## Local Development/Testing

- Create a **public** github repository like https://github.com/byroot/junk that
  contains a similar dummy `shipit.yml` file.
- Create an API key (https://github.com/settings/tokens/new) that has only
  public_repo permissions (Shipit doesn't need anything else) and add it in
  `config/secrets.yml` under `development.github_credentials.access_token`. Be
  careful with this key, it would give an attacker some permissions with your
  github account!
- Create a stack in your local Shipit that points to that repository.
- Make sure you have resque running (see below) in order for background jobs to
  work.
