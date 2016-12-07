module Shipit
  class StripCacheControl < Faraday::Middleware
    def call(request_env)
      @app.call(request_env).on_complete do |response_env|
        if headers = response_env[:response_headers]
          headers.delete('last-modified')
          directives = parse(headers['cache-control'].to_s)
          directives.delete('max-age')
          directives.delete('s-maxage')
          headers['cache-control'] = dump(directives)
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
