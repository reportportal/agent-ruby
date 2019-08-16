require 'faraday'
require_relative 'patches/faraday'

module ReportPortal
  class Client
    attr_accessor :logger

    def initialize(logger)
      @logger = logger
    end

    def process_request(path, method, *options)
      tries = 5
      begin
        response = rp_client.send(method, path, *options)
      rescue => e
        logger.warn("Exception[#{e}],class:[#{e.class}],class:[#{e.class}], retry_count: [#{tries}]")
        logger.error("TRACE[#{e.backtrace}]")
        response = JSON.parse(e.response)
        m = response['message'].match(%r{Start time of child \['(.+)'\] item should be same or later than start time \['(.+)'\] of the parent item\/launch '.+'})
        debugger
        if m
          parent_time = Time.strptime(m[2], '%a %b %d %H:%M:%S %z %Y')
          data = JSON.parse(options[0])
          logger.warn("RP error : 40025, time of a child: [#{data['start_time']}], paren time: [#{(parent_time.to_f * 1000).to_i}]")
          data['start_time'] = (parent_time.to_f * 1000).to_i + 1000
          options[0] = data.to_json
          ReportPortal.last_used_time = data['start_time']
        else
          logger.error("RestClient::Exception -> response: [#{response}]")
          logger.error("TRACE[#{e.backtrace}]")
          raise
        end

        retry unless (tries -= 1).zero?
      end
      logger.error("Response:[#{response.status}] [#{response.body}], r") unless response.status == 201
      JSON.parse(response.body)

    end

    def rp_client
      @connection ||= Faraday.new(url: Settings.instance.project_url) do |f|
        f.headers = {Authorization: "Bearer #{Settings.instance.uuid}", Accept: 'application/json', 'Content-type': 'application/json'}
        verify_ssl = Settings.instance.disable_ssl_verification
        f.ssl.verify = !verify_ssl unless verify_ssl.nil?
        f.request :multipart
        f.request :url_encoded
        f.adapter :net_http
      end

      @connection
    end
  end
  module ERROR
    class CustomErrors < Faraday::Response::Middleware
      def on_complete(env)
        debugger
        case env[:status]
        when 404
          raise RuntimeError, 'Custom 404 response'
        end
      end
    end
  end
end