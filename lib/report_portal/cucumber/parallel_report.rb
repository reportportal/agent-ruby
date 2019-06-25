require 'parallel_tests'
require 'sys/proctable'
require 'fileutils'
require_relative 'report'

module ReportPortal
  module Cucumber
    class ParallelReport < Report


      def initialize
        ReportPortal.last_used_time = 0
        @root_node = Tree::TreeNode.new('')
        @parent_item_node = @root_node

        set_parallel_tests_vars

        if ParallelTests.first_process?
          start_launch(ReportPortal.now)
        else
          start_time = monotonic_time
          loop do
            break if File.exist?(lock_file)
            if monotonic_time - start_time > wait_time_for_launch_create
              raise "File with launch ID wasn't created after waiting #{wait_time_for_launch_create} seconds"
            end

            sleep 0.5
          end
          ReportPortal.launch_id = read_lock_file(lock_file)
          add_process_description
        end
      end

      def add_process_description
        description = ReportPortal.remote_launch['description'].split(' ')
        description.push(self.description.split(' ')).flatten!
        ReportPortal.update_launch(description: description.uniq.join(' '))
      end

      def test_run_finished(_event, desired_time )
        end_feature(desired_time) unless @parent_item_node.is_root?

        if parallel
          if ParallelTests.first_process?
            ParallelTests.wait_for_other_processes_to_finish
            close_all_children_of(@root_node) # Folder items are closed here as they can't be closed after finishing a feature

            File.delete(lock_file)

            if started_launch || !attach_to_launch?
              time_to_send = time_to_send(desired_time)
              ReportPortal.finish_launch(time_to_send)
            end
          end
        else
          super(_event,desired_time)
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
        @cmd_args_of_parallel_tests = runner_process.cmdline.split(' ', 2).pop
      end

      def get_parallel_test_process(process_list)
        process_list.each do |process|
          if process.cmdline.match(%r{bin(?:\/|\\)parallel_(?:cucumber|test)(.+)})
            @parallel = true
            return process
          end
        end
        nil
      end

      def get_cucumber_test_process(process_list)
        process_list.each do |process|
          return process if process.cmdline.match(%r{bin(?:\/|\\)(?:cucumber)(.+)})
        end
        nil
      end

      def wait_time_for_launch_create
        ENV['rp_parallel_launch_wait_time'] || 60
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
