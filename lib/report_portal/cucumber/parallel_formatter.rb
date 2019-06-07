require_relative 'formatter'
require_relative 'parallel_report'
require 'parallel_tests/gherkin/io'

module ReportPortal
  module Cucumber
    class ParallelFormatter < Formatter
      #include ::ParallelTests::Gherkin::Io

      # @api private
      def initialize(config)
        ENV['REPORT_PORTAL_USED'] = 'true'

        @queue = Queue.new
        @thread = Thread.new do
          @report = ReportPortal::Cucumber::ParallelReport.new
          loop do
            method_arr = @queue.pop
            @report.public_send(*method_arr)
          end
        end
        @thread.abort_on_exception = true

        @io = config.out_stream

        [:test_case_started, :test_case_finished, :test_step_started, :test_step_finished].each do |event_name|
          config.on_event event_name do |event|
            @queue.push([event_name, event, ReportPortal.now])
          end
        end
        config.on_event :test_run_finished, &method(:on_test_run_finished)
      end
    end
  end
end
