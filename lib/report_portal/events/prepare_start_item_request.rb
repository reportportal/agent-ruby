module ReportPortal
  module Events
    # An event executed before sending a StartTestItem request.
    class PrepareStartItemRequest
      # A hash that contains keys like item's `start_time`, `name`, `description`.
      attr_reader :request_data

      def initialize(request_data:)
        @request_data = request_data
      end
    end
  end
end
