require 'thread'

require_relative 'report'

module ReportPortal
  module Cucumber
    class Formatter
      # @api private
      def initialize(config)
        ENV['REPORT_PORTAL_USED'] = 'true'

        @queue = Queue.new
        @thread = Thread.new do
          @report = ReportPortal::Cucumber::Report.new
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

      def puts(message)
        @queue.push([:puts, message, ReportPortal.now])
        @io.puts(message)
        @io.flush
      end

      def embed(*args)
        @queue.push([:embed, *args, ReportPortal.now])
      end

      def on_test_run_finished(_event)
        @queue.push([:done, ReportPortal.now])
        sleep 0.03 while !@queue.empty? || @queue.num_waiting == 0 # TODO: how to interrupt launch if the user aborted execution
        @thread.kill
      end
    end
  end
end
