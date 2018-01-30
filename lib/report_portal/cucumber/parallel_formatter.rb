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

module ReportPortal
  module Cucumber
    class ParallelFormatter < Formatter
      # @api private
      def initialize(config)
        @start_launch_time = ReportPortal.now
        super(config)
      end

      private

      def initialize_report
        @report = ReportPortal::Cucumber::ParallelReport.new(@start_launch_time, logger)
      end
    end
  end
end
