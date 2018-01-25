require_relative 'report'

module ReportPortal
  module Cucumber
    class ParallelReport < Report
      def parallel?
        true
      end

      def initialize(desired_time)
        @root_node = Tree::TreeNode.new('')
        ReportPortal.last_used_time = 0

        if ParallelTests.first_process?
          File.open(file_with_launch_id, 'w') do |f|
            f.flock(File::LOCK_EX)
            start_launch(desired_time)
            f.write(ReportPortal.launch_id)
            f.flush
            f.flock(File::LOCK_UN)
          end
        else
          loop do
            break if File.exist?(file_with_launch_id)
            sleep 0.5
          end
          File.open(file_with_launch_id, 'r') do |f|
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

          File.delete(file_with_launch_id)

          unless attach_to_launch?
            $stdout.puts "Finishing launch #{ReportPortal.launch_id}"
            ReportPortal.close_child_items(nil)
            time_to_send = time_to_send(desired_time)
            ReportPortal.finish_launch(time_to_send)
          end
        end
      end

      def file_with_launch_id
        Pathname(Dir.tmpdir) + "parallel_launch_id_for_#{pid_of_parallel_tests}.lck"
      end

      def pid_of_parallel_tests
        pid = Process.pid
        loop do
          current_process = Sys::ProcTable.ps(pid)
          raise 'Could not get parallel_cucumber in process tree' if current_process.nil?
          return current_process.pid if current_process.cmdline[/bin(?:\/|\\)parallel_cucumber/]
          pid = Sys::ProcTable.ps(pid).ppid
        end
      end
    end
  end
end
