# Copyright 2015 EPAM Systems
# 
# 
# This file is part of Report Portal.
# 
# Report Portal is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# ReportPortal is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with Report Portal.  If not, see <http://www.gnu.org/licenses/>.

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
        start_launch_time = ReportPortal.now
        @thread = Thread.new do
          @report = ReportPortal::Cucumber::ParallelReport.new(start_launch_time)
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
