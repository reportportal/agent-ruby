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

        [:before_test_case, :after_test_case, :before_test_step, :after_test_step].each do |event_name|
          config.on_event event_name do |event|
            @queue.push([event_name, event, ReportPortal.now])
          end
        end
      end

      def puts(message)
        @queue.push([:puts, message, ReportPortal.now])
        @io.puts(message)
        @io.flush
      end

      def embed(*args)
        @queue.push([:embed, *args, ReportPortal.now])
      end

      # @api private
      def done
        @queue.push([:done, ReportPortal.now])
        sleep 0.03 while !@queue.empty? || @queue.num_waiting == 0 # TODO: how to interrupt launch if the user aborted execution
        @thread.kill
      end
    end
  end
end
