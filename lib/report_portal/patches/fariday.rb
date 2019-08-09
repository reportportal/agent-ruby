class Faraday::Request::Multipart
  def create_multipart(env, params)
    boundary = env.request.boundary
    parts = process_params(params) do |key, value|
      if (JSON.parse(value) rescue false)
        Faraday::Parts::Part.new(boundary, key, value, 'Content-Type' => 'application/json')
      else
        Faraday::Parts::Part.new(boundary, key, value)
      end
    end
    parts << Faraday::Parts::EpiloguePart.new(boundary)

    body = Faraday::CompositeReadIO.new(parts)
    env.request_headers[Faraday::Env::ContentLength] = body.length.to_s
    return body
  end
end