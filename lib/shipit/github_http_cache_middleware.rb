module Shipit
  class GitHubHTTPCacheMiddleware < Faraday::Middleware
    def call(request_env)
      @app.call(request_env).on_complete do |response_env|
        if headers = response_env[:response_headers]

          # We're removing max-age and s-maxage because some endpoints,
          # especially /<repo>/commits, returns a max-age=0. This means that
          # if two commits are pushed within 1 minute of each others, we won't
          # see the second one. So instead we still issue the request, but we
          # revalidate it.
          cache_control = parse(headers['cache-control'].to_s)
          cache_control.delete('max-age')
          cache_control.delete('s-maxage')
          cache_control['no-cache'] = true
          cache_control['must-revalidate'] = true
          headers['cache-control'] = dump(cache_control)

          # We're removing `Authorization` from the `Vary` header because
          # Faraday::HttpCache has a very limited garbage collection support
          # and this cause cache entries to grow indefinitely.
          # See https://github.com/Shopify/shipit-engine/issues/935 for
          # more details.
          vary = parse(headers['vary'].to_s)
          vary.delete('authorization')
          headers['vary'] = dump(vary)
        end
      end
    end

    private

    def dump(directives)
      directives.map do |k, v|
        if v == true
          k
        else
          "#{k}=#{v}"
        end
      end.join(', ')
    end

    def parse(header)
      directives = {}

      header.delete(' ').split(',').each do |part|
        next if part.empty?

        name, value = part.split('=', 2)
        directives[name.downcase] = (value || true) unless name.empty?
      end

      directives
    end
  end
end
