require 'tree'
require 'securerandom'
require 'tempfile'
require 'parallel_tests'
require 'sys/proctable'
require 'fileutils'

require_relative '../../reportportal'
require_relative '../logging/logger'

module ReportPortal
  module Cucumber
    # @api private
    class Report
      attr_accessor :parallel, :started_launch

      def attach_to_launch?
        ReportPortal::Settings.instance.formatter_modes.include?('attach_to_launch')
      end

      def initialize(logger)
        @logger = logger
        ReportPortal.last_used_time = 0
        ReportPortal.initialize(logger)
        @root_node = Tree::TreeNode.new('')
        @parent_item_node = @root_node

        set_parallel_tests_vars

        if ParallelTests.first_process?
          @logger.debug("First process: #{@pid_of_parallel_tests}")
          start_launch(ReportPortal.now)
        else
          @logger.debug("Child process: #{@pid_of_parallel_tests}")
          start_time = monotonic_time
          loop do
            break if File.exist?(lock_file)
            if monotonic_time - start_time > wait_time_for_launch_create
              raise "File with launch ID wasn't created after waiting #{wait_time_for_launch_create} seconds"
            end

            @logger.debug "File with launch ID wasn't created after waiting #{monotonic_time - start_time} seconds"

            sleep 0.5
          end
          ReportPortal.launch_id = read_lock_file(lock_file)
          @logger.debug "Attaching to launch using lock_file [#{lock_file}], launch_id: [#{ReportPortal.launch_id}] "
          add_process_description
        end
      end

      def start_launch(desired_time, cmd_args = ARGV)
        if attach_to_launch?
          ReportPortal.launch_id =
            if ReportPortal::Settings.instance.launch_id
              ReportPortal::Settings.instance.launch_id
            else
              file_path = lock_file
              if File.file?(file_path)
                read_lock_file(file_path)
              else
                self.started_launch = true
                new_launch(desired_time, cmd_args, file_path)
              end
            end
          @logger.info "Attaching to launch #{ReportPortal.launch_id}"
        else
          new_launch(desired_time, cmd_args)
        end
      end

      def new_launch(desired_time, cmd_args = ARGV, lock_file = nil)
        @logger.info("Creating new launch at: [#{desired_time}], with cmd: [#{cmd_args}] and file lock: [#{lock_file}]")
        ReportPortal.start_launch(description(cmd_args), time_to_send(desired_time))
        set_file_lock_with_launch_id(lock_file, ReportPortal.launch_id) if lock_file
        ReportPortal.launch_id
      end

      def description(cmd_args = ARGV)
        description ||= ReportPortal::Settings.instance.description
        description ||= cmd_args.map { |arg| arg.gsub(/rp_uuid=.+/, "rp_uuid=[FILTERED]") }.join(' ')
        description
      end

      def set_file_lock_with_launch_id(lock_file, launch_id)
        FileUtils.mkdir_p File.dirname(lock_file)
        File.open(lock_file, 'w') do |f|
          f.flock(File::LOCK_EX)
          f.write(launch_id)
          f.flush
          f.flock(File::LOCK_UN)
        end
      end

      # scenario starts in separate treads
      def test_case_started(event, desired_time)
        @logger.debug "test_case_started: [#{event}], "
        test_case = event.test_case
        feature = test_case.feature
        if report_hierarchy? && !same_feature_as_previous_test_case?(feature)
          end_feature(desired_time) unless @parent_item_node.is_root?
          start_feature_with_parentage(feature, desired_time)
        end

        name = "#{test_case.keyword}: #{test_case.name}"
        description = test_case.location.to_s
        tags = test_case.tags.map(&:name)
        type = :STEP

        ReportPortal.current_scenario = ReportPortal::TestItem.new(name, type, nil, time_to_send(desired_time), description, false, tags)
        scenario_node = Tree::TreeNode.new(SecureRandom.hex, ReportPortal.current_scenario)
        @parent_item_node << scenario_node
        ReportPortal.current_scenario.id = ReportPortal.start_item(scenario_node)
      end

      def test_case_finished(event, desired_time)
        @logger.debug "test_case_finished: [#{event}], "
        result = event.result
        status = result.to_sym
        issue = nil
        if [:undefined, :pending].include?(status)
          status = :failed
          issue = result.message
        end
        ReportPortal.finish_item(ReportPortal.current_scenario, status, time_to_send(desired_time), issue)
        ReportPortal.current_scenario = nil
      end

      def test_step_started(event, desired_time)
        @logger.debug "test_step_started: [#{event}], "
        test_step = event.test_step
        if step?(test_step) # `after_test_step` is also invoked for hooks
          step_source = test_step.source.last
          message = "-- #{step_source.keyword}#{step_source.text} --"
          if step_source.multiline_arg.doc_string?
            message << %(\n"""\n#{step_source.multiline_arg.content}\n""")
          elsif step_source.multiline_arg.data_table?
            message << step_source.multiline_arg.raw.reduce("\n") { |acc, row| acc << "| #{row.join(' | ')} |\n" }
          end
          ReportPortal.send_log(:trace, message, time_to_send(desired_time))
        end
      end

      def test_step_finished(event, desired_time)
        test_step = event.test_step
        result = event.result
        status = result.to_sym

        if [:failed, :pending, :undefined].include?(status)
          exception_info = if [:failed, :pending].include?(status)
                             ex = result.exception
                             sprintf("%s: %s\n  %s", ex.class.name, ex.message, ex.backtrace.join("\n  "))
                           else
                             sprintf("Undefined step: %s:\n%s", test_step.text, test_step.source.last.backtrace_line)
                           end
          ReportPortal.send_log(:error, exception_info, time_to_send(desired_time))
        end

        if status != :passed
          log_level = (status == :skipped) ? :warn : :error
          step_type = if step?(test_step)
                        'Step'
                      else
                        hook_class_name = test_step.source.last.class.name.split('::').last
                        location = test_step.location
                        "#{hook_class_name} at `#{location}`"
                      end
          ReportPortal.send_log(log_level, "#{step_type} #{status}", time_to_send(desired_time))
        end
      end

      def test_run_finished(_event, desired_time)
        end_feature(desired_time) unless @parent_item_node.is_root?
        @logger.info("Test run finish: [#{@parent_item_node}]")
        close_all_children_of(@root_node) # Folder items are closed here as they can't be closed after finishing a feature
        if parallel
          @logger.debug("Parallel process: #{@pid_of_parallel_tests}")
          if ParallelTests.first_process? && started_launch
            ParallelTests.wait_for_other_processes_to_finish
            File.delete(lock_file)
            @logger.info("close launch , delete lock")
            complete_launch(desired_time)
          end
        else
          complete_launch(desired_time)
        end
      end

      def add_process_description
        description = ReportPortal.remote_launch['description'].split(' ')
        description.push(self.description.split(' ')).flatten!
        ReportPortal.update_launch(description: description.uniq.join(' '))
      end

      def puts(message, desired_time)
        ReportPortal.send_log(:info, message, time_to_send(desired_time))
      end

      def embed(src, mime_type, label, desired_time)
        ReportPortal.send_file(:info, src, label, time_to_send(desired_time), mime_type)
      end

      private

      def complete_launch(desired_time)
        if started_launch || !attach_to_launch?
          time_to_send = time_to_send(desired_time)
          ReportPortal.finish_launch(time_to_send)
        end
      end

      def lock_file(file_path = nil)
        file_path ||= ReportPortal::Settings.instance.file_with_launch_id
        @logger.debug("Lock file (RReportPortal::Settings.instance.file_with_launch_id): #{file_path}") if file_path
        file_path ||= Dir.tmpdir + "/report_portal_#{ReportPortal::Settings.instance.launch_uuid}.lock" if ReportPortal::Settings.instance.launch_uuid
        @logger.debug("Lock file (ReportPortal::Settings.instance.launch_uuid): #{file_path}") if file_path
        file_path ||= Dir.tmpdir + "/rp_launch_id_for_#{@pid_of_parallel_tests}.lock" if @pid_of_parallel_tests
        @logger.debug("Lock file (/rp_launch_id_for_#{@pid_of_parallel_tests}.lock): #{file_path}") if file_path

        file_path
      end

      def set_parallel_tests_vars
        process_list = Sys::ProcTable.ps
        @logger.debug("set_test_variables: #{process_list}")
        runner_process ||= get_parallel_test_process(process_list)
        @logger.debug("Parallel cucumber runner pid: #{runner_process.pid}") if runner_process
        runner_process ||= get_cucumber_test_process(process_list)
        @logger.debug("Cucumber runner pid: #{runner_process.pid}") if runner_process
        raise 'Failed to find any cucumber related test process' if runner_process.nil?

        @pid_of_parallel_tests = runner_process.pid
      end

      def get_parallel_test_process(process_list)
        process_list.each do |process|
          next unless process.cmdline.match(%r{bin(?:\/|\\)parallel_(?:cucumber|test)(.+)})
          @parallel = true
          @logger.debug("get_parallel_test_process: #{process.cmdline}")
          return process
        end
        nil
      end

      def get_cucumber_test_process(process_list)
        process_list.each do |process|
          if process.cmdline.match(%r{bin(?:\/|\\)(?:cucumber)(.+)})
            @logger.debug("get_cucumber_test_process: #{process.cmdline}")
            return process
          end
        end
        nil
      end

      def wait_time_for_launch_create
        ENV['rp_parallel_launch_wait_time'] || 60
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def read_lock_file(file_path)
        content = nil
        File.open(file_path, 'r') do |f|
          f.flock(File::LOCK_SH)
          content = File.read(file_path)
          f.flock(File::LOCK_UN)
        end
        content
      end

      # Report Portal sorts logs by time. However, several logs might have the same time.
      #   So to get Report Portal sort them properly the time should be different in all logs related to the same item.
      #   And thus it should be stored.
      # Only the last time needs to be stored as:
      #   * only one test framework process/thread may send data for a single Report Portal item
      #   * that process/thread can't start the next test until it's done with the previous one
      def time_to_send(desired_time)
        time_to_send = desired_time
        if time_to_send <= ReportPortal.last_used_time
          time_to_send = ReportPortal.last_used_time + 1
        end
        ReportPortal.last_used_time = time_to_send
      end

      def same_feature_as_previous_test_case?(feature)
        @parent_item_node.name == feature.location.file.split(File::SEPARATOR).last
      end

      def start_feature_with_parentage(feature, desired_time)
        @logger.debug("start_feature_with_parentage: [#{feature}], [#{desired_time}]")
        parent_node = @root_node
        child_node = nil
        path_components = feature.location.file.split(File::SEPARATOR)
        path_components.each_with_index do |path_component, index|
          child_node = parent_node[path_component]
          unless child_node # if child node was not created yet
            if index < path_components.size - 1
              name = "Folder: #{path_component}"
              description = nil
              tags = []
              type = :SUITE
            else
              name = "#{feature.keyword}: #{feature.name}"
              description = feature.file # TODO: consider adding feature description and comments
              tags = feature.tags.map(&:name)
              type = :TEST
            end
            # TODO: multithreading # Parallel formatter always executes scenarios inside the same feature in the same process
            if parallel &&
               index < path_components.size - 1 && # is folder?
               (id_of_created_item = ReportPortal.item_id_of(name, parent_node)) # get id for folder from report portal
              # get child id from other process
              item = ReportPortal::TestItem.new(name, type, id_of_created_item, time_to_send(desired_time), description, false, tags)
              child_node = Tree::TreeNode.new(path_component, item)
              parent_node << child_node
            else
              item = ReportPortal::TestItem.new(name, type, nil, time_to_send(desired_time), description, false, tags)
              child_node = Tree::TreeNode.new(path_component, item)
              parent_node << child_node
              item.id = ReportPortal.start_item(child_node) # TODO: multithreading
            end
          end
          parent_node = child_node
        end
        @parent_item_node = child_node
      end

      def end_feature(desired_time)
        ReportPortal.finish_item(@parent_item_node.content, nil, time_to_send(desired_time))
        # Folder items can't be finished here because when the folder started we didn't track
        #   which features the folder contains.
        # It's not easy to do it using Cucumber currently:
        #   https://github.com/cucumber/cucumber-ruby/issues/887
      end

      def close_all_children_of(root_node)
        @logger.debug("close_all_children_of: [#{root_node.children}]")
        root_node.postordered_each do |node|
          @logger.debug("close_all_children_of:postordered_each [#{node.content}]")
          unless node.is_root? || node.content.closed
            begin
              item = ReportPortal.remote_item(node.content[:id])
              @logger.debug("started_launch?: [#{started_launch}], item details: [#{item}]")
              if item.key?('end_time')
                started_launch ? @logger.warn("Main process: item already closed skipping.") : ReportPortal.finish_item(node.content)
              elsif started_launch
                ReportPortal.close_child_items(node.content[:id])
                ReportPortal.finish_item(node.content)
              else
                @logger.warn("Child process: item in use cannot close it. [#{item}]")
              end
            end
          end
        end
      end

      def step?(test_step)
        !::Cucumber::Formatter::HookQueryVisitor.new(test_step).hook?
      end

      def report_hierarchy?
        !ReportPortal::Settings.instance.formatter_modes.include?('skip_reporting_hierarchy')
      end
    end
  end
end
