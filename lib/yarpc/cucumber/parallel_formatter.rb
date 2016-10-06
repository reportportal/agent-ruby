# Copyright 2015 EPAM Systems
# 
# 
# This file is part of YARPC.
# 
# YARPC is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# YARPC is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with YARPC.  If not, see <http://www.gnu.org/licenses/>.

require_relative 'formatter'
require_relative 'parallel_report'
require 'parallel_tests/gherkin/io'

module YARPC
  module Cucumber
    class ParallelFormatter < Formatter
      #include ::ParallelTests::Gherkin::Io

      # @api private
      def initialize(_runtime, path_or_io, options)
        ENV['REPORT_PORTAL_USED'] = 'true'

        @queue = Queue.new
        @thread = Thread.new do
          @report = YARPC::Cucumber::ParallelReport.new(_runtime, path_or_io, options, YARPC.now)
          while method_arr = @queue.pop
            @report.public_send(*method_arr)
          end
        end
        @thread.abort_on_exception = true

        @io = ensure_io(path_or_io)
      end
    end
  end
end
