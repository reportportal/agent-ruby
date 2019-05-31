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
        set_parallel_tests_vars
        if ParallelTests.first_process?
          start_launch(desired_time)
        else
          start_time = monotonic_time
          loop do
            break if File.exist?(lock_file)
            if monotonic_time - start_time > wait_time_for_launch_start
              raise "File with launch ID wasn't created after waiting #{wait_time_for_launch_start} seconds"
            end
            sleep 0.5
          end
          sleep_time = 5
          sleep(sleep_time) # stagger start times for reporting to Report Portal to avoid collision

          File.open(lock_file, 'r') do |f|
            ReportPortal.launch_id = f.read
          end
          add_process_description
        end
      end

      def add_process_description
        description = ReportPortal.get_launch['description'].split(' ')
        description.push(self.description().split(' ')).flatten!
        ReportPortal.update_launch({description: description.uniq.join(' ')})
      end

      def done(desired_time = ReportPortal.now)
        end_feature(desired_time) if @feature_node

        if ParallelTests.first_process?
          ParallelTests.wait_for_other_processes_to_finish

          File.delete(lock_file)

          # TODO: if parallel test does not need to finish launch, there should be env variable to support this.
          #  as report launch is is created by first process it should also be finished by same process
          unless ReportPortal::Settings.instance.launch_id || ReportPortal::Settings.instance.file_with_launch_id
            ReportPortal.close_child_items(nil)
            time_to_send = time_to_send(desired_time)
            ReportPortal.finish_launch(time_to_send)
          end
        end
      end

      def lock_file(file_path = nil)
        file_path ||= Dir.tmpdir + "parallel_launch_id_for_#{@pid_of_parallel_tests}.lock"
        super(file_path)
      end

      private

      def set_parallel_tests_vars
        pid = Process.pid
        loop do
          #FIXME failing in jenkins
          current_process = Sys::ProcTable.ps(pid)
          #TODO: add exception to fall back to cucumber process 
          # 1. if rm_launch_uuid was created by some other parallel script that executes cucumber batch of feature files
          # 2. if fallback to cucumber process, this allows to use same formatter sequential and parallel executions
          # useful when formatters are default configured in AfterConfiguration hook 
          # config.formats.push(["ReportPortal::Cucumber::ParallelFormatter", {}, set_up_output_format(report_name, :report_portal)])
          raise 'Could not find parallel_cucumber/parallel_test in ancestors of current process' if current_process.nil?
          match = current_process.cmdline.match(/bin(?:\/|\\)parallel_(?:cucumber|test)(.+)/)
          if match
            @pid_of_parallel_tests = current_process.pid
            @cmd_args_of_parallel_tests = match[1].strip.split
            break
          end
          pid = Sys::ProcTable.ps(pid).ppid
        end
      end

      #time required for first tread to created remote project in RP and save id to file
      def wait_time_for_launch_start
        ENV['rp_parallel_launch_wait_time'] ? ENV['rp_parallel_launch_wait_time'] : 60
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
