module Faraday
  class Request
    # Middleware for supporting multi-part requests.
    class Multipart
      def create_multipart(env, params)
        boundary = env.request.boundary
        parts = process_params(params) do |key, value|
          if begin
            JSON.parse(value)
             rescue StandardError
               false
          end
            Faraday::Parts::Part.new(boundary, key, value, 'Content-Type' => 'application/json')
          else
            Faraday::Parts::Part.new(boundary, key, value)
          end
        end
        parts << Faraday::Parts::EpiloguePart.new(boundary)
        body = Faraday::CompositeReadIO.new(parts)
        env.request_headers[Faraday::Env::ContentLength] = body.length.to_s
        body
      end
    end
  end
end
