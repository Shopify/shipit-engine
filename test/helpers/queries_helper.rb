# frozen_string_literal: true

module QueriesHelper
  def assert_no_queries(ignored_sql = nil, &block)
    assert_queries(0, ignored_sql, &block)
  end

  def assert_queries(num = 1, ignored_sql = nil)
    counter = SQLCounter.new(ignored_sql)
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record', counter)
    yield counter
    queries = counter.log.empty? ? '' : "\nQueries:\n#{counter.log.join("\n")}"
    assert_equal(num, counter.log.size, "#{counter.log.size} instead of #{num} queries were executed.#{queries}")
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  class SQLCounter
    cattr_accessor :ignored_sql
    self.ignored_sql = [
      /^PRAGMA (?!(table_info))/,
      /^SELECT currval/,
      /^SELECT CAST/,
      /^SELECT @@IDENTITY/,
      /^SELECT @@ROWCOUNT/,
      /^SELECT @@FOREIGN_KEY_CHECKS/,
      /^SET FOREIGN_KEY_CHECKS/,
      /^SAVEPOINT/,
      /^ROLLBACK TO SAVEPOINT/,
      /^RELEASE SAVEPOINT/,
      /^SHOW max_identifier_length/,
      /^BEGIN/,
      /^COMMIT/,
      /^SHOW FULL FIELDS/,
      /^SHOW TABLES LIKE/,
    ]

    # FIXME: this needs to be refactored so specific database can add their own
    # ignored SQL.  This ignored SQL is for Oracle.
    ignored_sql.push(/^select .*nextval/i, /^SAVEPOINT/, /^ROLLBACK TO/, /^\s*select .* from all_triggers/im)

    attr_reader :ignore
    attr_reader :log

    def initialize(ignore = nil)
      @ignore = ignore || self.class.ignored_sql
      @log = []
    end

    def call(_name, _start, _finish, _message_id, values)
      sql = values[:sql]

      # FIXME: this seems bad. we should probably have a better way to indicate
      # the query was cached
      return if values[:name] == 'CACHE' || ignore.any? { |x| x =~ sql }

      log << sql
    end
  end
end
