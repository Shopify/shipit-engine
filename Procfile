worker: RAILS_ENV=$SHIPIT_ENV TERM_CHILD=1 QUEUE=* bundle exec rake resque:work
web: bundle exec thin start -p $PORT -e $SHIPIT_ENV --max-persistent-conns 256
migrations: RAILS_ENV=$SHIPIT_ENV bundle exec rake db:migrate
