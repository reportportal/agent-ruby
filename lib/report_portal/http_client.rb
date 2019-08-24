require 'http'

module ReportPortal
  # @api private
  class HttpClient
    def initialize
      create_persistent_client
    end

    def send_request(verb, path, options = {})
      path.prepend("/api/v1/#{Settings.instance.project}/")
      3.times do
        begin
          response = @http.request(verb, path, options)
        rescue StandardError => e
          puts "Request #{request_info(verb, path)} produced an exception:"
          puts e
          recreate_persistent_client
        else
          return response.parse(:json) if response.status.success?

          message = "Request #{request_info(verb, path)} returned code #{response.code}."
          message << " Response:\n#{response}" unless response.to_s.empty?
          puts message
        end
      end
    end

    private

    def create_persistent_client
      @http = HTTP.persistent(origin).auth("Bearer #{Settings.instance.uuid}")
      add_insecure_ssl_options if Settings.instance.disable_ssl_verification
    end

    def add_insecure_ssl_options
      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
      @http.default_options = { ssl_context: ssl_context }
    end

    # Response should be consumed before sending next request via the same persistent connection.
    # If an exception occurred, there may be no response so a connection has to be recreated.
    def recreate_persistent_client
      @http.close
      create_persistent_client
    end

    def request_info(verb, path)
      uri = URI.join(origin, path)
      "#{verb.upcase} `#{uri}`"
    end

    def origin
      Addressable::URI.parse(Settings.instance.endpoint).origin
    end
  end
end
