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

require_relative 'report'

module ReportPortal
  module Cucumber
    class ParallelReport < Report
      FILE_WITH_LAUNCH_ID = Pathname(Dir.tmpdir) + "parallel_launch_id_for_#{Process.ppid}.lck"

      def parallel?
        true
      end

      def initialize
        @root_node = Tree::TreeNode.new('')
        @last_used_time ||= 0

        if ParallelTests.first_process?
          File.open(FILE_WITH_LAUNCH_ID, 'w') do |f|
            f.flock(File::LOCK_EX)
            start_launch
            f.write(ReportPortal.launch_id)
            f.flush
            f.flock(File::LOCK_UN)
          end
        else
          File.open(FILE_WITH_LAUNCH_ID, 'r') do |f|
            f.flock(File::LOCK_SH)
            ReportPortal.launch_id = f.read
            f.flock(File::LOCK_UN)
          end
        end
      end

      def done(desired_time = ReportPortal.now)
        end_feature(desired_time) if @feature_node

        if ParallelTests.first_process?
          ParallelTests.wait_for_other_processes_to_finish

          File.delete(FILE_WITH_LAUNCH_ID)

          unless attach_to_launch?
            $stdout.puts "Finishing launch #{ReportPortal.launch_id}"
            ReportPortal.close_child_items(nil)
            time_to_send = time_to_send(desired_time)
            ReportPortal.finish_launch(time_to_send)
          end
        end
      end
    end
  end
end
