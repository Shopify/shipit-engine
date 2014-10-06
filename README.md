# :shipit: Next

[![PC Gamma](http://burkelibbey.s3.amazonaws.com/gamma.png)](https://vault.shopify.com/Project-Classification)
[![Build Status](https://circleci.com/gh/Shopify/shipit2.png?circle-token=d265c5aba111546b090376fe314f396caa01c70c)](https://circleci.com/gh/Shopify/shipit2)

http://hack-days.herokuapp.com/projects/91

## Classification Checklist

- [ ] Setup scripts following the Borg conventions
- [X] Test suite running on CI
- [ ] Deploy script
- [X] Shipit.yml
- [ ] Pingdom
- [X] Errbit
- [ ] S3 data backup
- [ ] Datadog dashboard a newbie can look at and understand
- [X] Logs in splunk
- [ ] Security review
- [ ] No core resources are destroyed from the database, only soft deleted
- [ ] No single points of failure
- [ ] Documented failover procedures

## Setup

```shell
$ git clone git@github.com:Shopify/shipit2.git
$ cd shipit2
$ script/bootstrap
```

## Jobs

```shell
# run workers for deploy jobs
QUEUE=deploys rake resque:work

# start-stop resque-web
resque-web
resque-web -K
```

