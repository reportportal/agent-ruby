require 'parallel_tests'

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
        @parent_item_node = @root_node
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

      def test_run_finished(_event, desired_time = ReportPortal.now)
        end_feature(desired_time) unless @parent_item_node.is_root?

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
