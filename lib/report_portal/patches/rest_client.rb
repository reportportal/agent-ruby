# monkey-patch to temporarily solve the issue in https://github.com/rest-client/rest-client/pull/222
module RestClient
  module Payload
    extend self
    class Multipart < Base
      def build_stream(params)
        content_type = params.delete(:content_type)
        b = '--' + boundary

        @stream = Tempfile.new("RESTClient.Stream.#{rand(1000)}")
        @stream.binmode
        @stream.write(b + EOL)

        case params
        when Hash, ParamsArray
          x = Utils.flatten_params(params)
        else
          x = params
        end

        last_index = x.length - 1
        x.each_with_index do |a, index|
          k, v = * a
          if v.respond_to?(:read) && v.respond_to?(:path)
            create_file_field(@stream, k, v)
          else
            create_regular_field(@stream, k, v, content_type)
          end
          @stream.write(EOL + b)
          @stream.write(EOL) unless last_index == index
        end
        @stream.write('--')
        @stream.write(EOL)
        @stream.seek(0)
      end

      def create_regular_field(s, k, v, type = nil)
        s.write("Content-Disposition: form-data; name=\"#{k}\"")
        s.write("#{EOL}Content-Type: #{type}#{EOL}") if type
        s.write(EOL)
        s.write(v)
      end
    end
  end
end
