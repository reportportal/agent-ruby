require 'parallel_tests'
require 'sys/proctable'
require 'fileutils'
require_relative 'report'

module ReportPortal
  module Cucumber
    class ParallelReport < Report

      def parallel?
        true
      end

      def initialize()
        @root_node = Tree::TreeNode.new('')
        ReportPortal.last_used_time = 0
        set_parallel_tests_vars
        if ParallelTests.first_process?
          start_launch()
        else
          start_time = monotonic_time
          loop do
            break if File.exist?(lock_file)
            if monotonic_time - start_time > wait_time_for_launch_start
              raise "File with launch ID wasn't created after waiting #{wait_time_for_launch_start} seconds"
            end
            sleep 0.5
          end
          ReportPortal.launch_id = read_lock_file(lock_file)
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

      private

      def lock_file(file_path = nil)
        file_path ||= Dir.tmpdir + "/parallel_launch_id_for_#{@pid_of_parallel_tests}.lock"
        super(file_path)
      end

      def set_parallel_tests_vars
        process_list = Sys::ProcTable.ps
        runner_process ||= get_parallel_test_process(process_list)
        runner_process ||= get_cucumber_test_process(process_list)
        raise 'Could not find parallel_cucumber/parallel_test in ancestors of current process' if runner_process.nil?
        @pid_of_parallel_tests = runner_process.pid
        @cmd_args_of_parallel_tests = runner_process.cmdline.split(' ',2).pop
      end

      def get_parallel_test_process(process_list)
        process_list.each do |process|
          return process if process.cmdline.match(/bin(?:\/|\\)parallel_(?:cucumber|test)(.+)/)
        end
        nil
      end

      def get_cucumber_test_process(process_list)
        process_list.each do |process|
          return process if process.cmdline.match(/bin(?:\/|\\)(?:cucumber)(.+)/)
        end
        nil
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
