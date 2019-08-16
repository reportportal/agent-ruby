module ReportPortal
  # @api private
  class Client
    attr_accessor :logger

    def initialize(logger)
      @logger = logger
    end

    def process_request(path, method, *options)
      tries = 2
      begin
        response = rp_client.send(method, path, *options)
      rescue Faraday::ClientError => e
        logger.error("TRACE[#{e.backtrace}]")
        response = JSON.parse(e.response[:body])
        logger.warn("Exception[#{e}], response:[#{response}]], retry_count: [#{tries}]")
        m = response['message'].match(%r{Start time of child \['(.+)'\] item should be same or later than start time \['(.+)'\] of the parent item\/launch '.+'})
        case response['error_code']
        when 4001
          return
        end

        if m
          parent_time = Time.strptime(m[2], '%a %b %d %H:%M:%S %z %Y')
          data = JSON.parse(options[0])
          logger.warn("RP error : 40025, time of a child: [#{data['start_time']}], paren time: [#{(parent_time.to_f * 1000).to_i}]")
          data['start_time'] = (parent_time.to_f * 1000).to_i + 1000
          options[0] = data.to_json
          ReportPortal.last_used_time = data['start_time']
        end

        retry unless (tries -= 1).zero?
      end
      JSON.parse(response.body)
    end

    def rp_client
      @connection ||= Faraday.new(url: Settings.instance.project_url) do |f|
        f.headers = { Authorization: "Bearer #{Settings.instance.uuid}", Accept: 'application/json', 'Content-type': 'application/json' }
        verify_ssl = Settings.instance.disable_ssl_verification
        f.ssl.verify = !verify_ssl unless verify_ssl.nil?
        f.request :multipart
        f.request :url_encoded
        f.response :raise_error
        f.adapter :net_http_persistent
      end

      @connection
    end
  end
end
