require File.dirname(__FILE__) + '/formatter'
require File.dirname(__FILE__) + '/parallel_report'

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
