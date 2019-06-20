require_relative 'formatter'
require_relative 'parallel_report'

module ReportPortal
  module Cucumber
    class ParallelFormatter < Formatter
      private

      def report
        @report ||= ReportPortal::Cucumber::ParallelReport.new
      end
    end
  end
end
