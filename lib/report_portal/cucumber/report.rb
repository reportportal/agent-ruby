require 'cucumber/formatter/io'
require 'cucumber/formatter/hook_query_visitor'
require 'tree'
require 'securerandom'

require_relative '../../reportportal'
require_relative '../logging/logger'

module ReportPortal
  module Cucumber
    # @api private
    class Report

      @folder_creation_tracking_file = Pathname(Dir.tmpdir)  + "folder_creation_tracking.lck"

      def parallel?
        false
      end

      def attach_to_launch?
        ReportPortal::Settings.instance.formatter_modes.include?('attach_to_launch')
      end

      def initialize
        ReportPortal.last_used_time = 0
        @root_node = Tree::TreeNode.new('')
        start_launch
      end

      def start_launch(desired_time = ReportPortal.now, cmd_args = ARGV)
        # Not sure what is the use case if launch id is missing. But it does not make much of practical usage
        #
        # Expected behavior that make sense:
        #  1. If launch_id present attach to existing (simple use case)
        #  2. If launch_id not present check if exist rp_launch_id.tmp
        #  3. [ADDED] If launch_id is not present check if lock exist with launch_uuid
        if attach_to_launch?
          ReportPortal.launch_id =
              if ReportPortal::Settings.instance.launch_id
                ReportPortal::Settings.instance.launch_id
              else
                file_path = lock_file
                if File.file?(file_path)
                  File.read(file_path)
                else
                  new_launch(desired_time, cmd_args, file_path)
                end
              end
          $stdout.puts "Attaching to launch #{ReportPortal.launch_id}"

        else
          new_launch(desired_time, cmd_args)
        end
      end

      def lock_file
        file_path ||= ReportPortal::Settings.instance.file_with_launch_id
        file_path ||= tmp_dir + "report_portal_#{ReportPortal::Settings.instance.launch_uuid}.lock" if ReportPortal::Settings.instance.launch_uuid
        file_path ||= tmp_dir + 'rp_launch_id.tmp'
        file_path
      end

      def new_launch(desired_time = ReportPortal.now, cmd_args = ARGV, lock_file = nil)
        description = ReportPortal::Settings.instance.description
        description ||= cmd_args.map {|arg| arg.gsub(/rp_uuid=.+/, "rp_uuid=[FILTERED]")}.join(' ')
        ReportPortal.start_launch(description, time_to_send(desired_time))
        set_file_lock_with_launch_id(lock_file, ReportPortal.launch_id) if lock_file
        ReportPortal.launch_id
      end

      def set_file_lock_with_launch_id(lock_file, launch_id)
        FileUtils.mkdir_p lock_file.dirname
        File.open(lock_file, 'w') do |f|
          f.flock(File::LOCK_EX)
          f.write(launch_id)
          f.flush
          f.flock(File::LOCK_UN)
        end
      end

      def test_case_started(event, desired_time = ReportPortal.now) # TODO: time should be a required argument
        test_case = event.test_case
        feature = test_case.feature
        unless same_feature_as_previous_test_case?(feature)
          end_feature(desired_time) if @feature_node
          start_feature_with_parentage(feature, desired_time)
        end

        name = "#{test_case.keyword}: #{test_case.name}"
        description = test_case.location.to_s
        tags = test_case.tags.map(&:name)
        type = :STEP

        ReportPortal.current_scenario = ReportPortal::TestItem.new(name, type, nil, time_to_send(desired_time), description, false, tags)
        scenario_node = Tree::TreeNode.new(SecureRandom.hex, ReportPortal.current_scenario)
        @feature_node << scenario_node
        ReportPortal.current_scenario.id = ReportPortal.start_item(scenario_node)
      end

      def test_case_finished(event, desired_time = ReportPortal.now)
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

      def test_step_started(event, desired_time = ReportPortal.now)
        test_step = event.test_step
        if step?(test_step) # `after_test_step` is also invoked for hooks
          step_source = test_step.source.last
          message = "-- #{step_source.keyword}#{step_source.text} --"
          if step_source.multiline_arg.doc_string?
            message << %(\n"""\n#{step_source.multiline_arg.content}\n""")
          elsif step_source.multiline_arg.data_table?
            message << step_source.multiline_arg.raw.reduce("\n") {|acc, row| acc << "| #{row.join(' | ')} |\n"}
          end
          ReportPortal.send_log(:trace, message, time_to_send(desired_time))
        end
      end

      def test_step_finished(event, desired_time = ReportPortal.now)
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

      def done(desired_time = ReportPortal.now)
        end_feature(desired_time) if @feature_node

        unless attach_to_launch?
          close_all_children_of(@root_node) # Folder items are closed here as they can't be closed after finishing a feature
          time_to_send = time_to_send(desired_time)
          ReportPortal.finish_launch(time_to_send)
        end
      end

      def puts(message, desired_time = ReportPortal.now)
        ReportPortal.send_log(:info, message, time_to_send(desired_time))
      end

      def embed(src, mime_type, label, desired_time = ReportPortal.now)
        ReportPortal.send_file(:info, src, label, time_to_send(desired_time), mime_type)
      end

      private

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

      def tmp_dir
        Pathname(ENV['TMPDIR'] ? ENV['TMPDIR'] : Dir.tmpdir)
      end

      def same_feature_as_previous_test_case?(feature)
        @feature_node && @feature_node.name == feature.location.file.split(File::SEPARATOR).last
      end

      def start_feature_with_parentage(feature, desired_time)
        parent_node = @root_node
        child_node = nil
        path_components = feature.location.file.split(File::SEPARATOR)
        path_components_no_feature = feature.location.file.split(File::SEPARATOR)[0...path_components.size - 1]
        path_components.each_with_index do |path_component, index|
          child_node = parent_node[path_component]
          unless child_node # if child node was not created yet
            if index < path_components.size - 1
              name = "Folder: #{path_component}"
              description = nil
              tags = []
              type = :SUITE
            else
              # TODO: Consider adding feature description and comments.
              name = "#{feature.keyword}: #{feature.name}"
              description = feature.file
              tags = feature.tags.map(&:name)
              type = :TEST
            end
            is_created = false
            if parallel? && name.include?("Folder:")
              folder_name = name.gsub("Folder: ", "")
              folder_name_for_tracker = "./#{folder_name}" # create a full path file name to use for tracking
              if index > 0
                folder_name_for_tracker = "./"
                for path_index in (0...path_components_no_feature.length)
                  folder_name_for_tracker += "#{path_components_no_feature[path_index]}/"
                end
              end
              @folder_creation_tracking_file = (Pathname(Dir.tmpdir)) + "folder_creation_tracking_#{ReportPortal.launch_id}.lck"
              File.open(@folder_creation_tracking_file, 'r+') do |f|
                f.flock(File::LOCK_SH)
                report_portal_folders = f.read
                if report_portal_folders
                  report_portal_folders_array = report_portal_folders.split(/\n/)
                  if report_portal_folders_array.include?(folder_name_for_tracker)
                    is_created = true
                  end
                end
                f.flock(File::LOCK_UN)
              end
              unless is_created
                File.open(@folder_creation_tracking_file, 'a') do |f|
                  f.flock(File::LOCK_EX)
                  f.write("\n#{folder_name_for_tracker}")
                  f.flush
                  f.flock(File::LOCK_UN)
                end
              end
            end
            if parallel? && index < path_components.size - 1 && is_created
              id_of_created_item = ReportPortal.item_id_of(name, parent_node)
              item = ReportPortal::TestItem.new(name, type, id_of_created_item, time_to_send(desired_time), description, false, tags)
              child_node = Tree::TreeNode.new(path_component, item)
              parent_node << child_node
            else
              item = ReportPortal::TestItem.new(name, type, nil, time_to_send(desired_time), description, false, tags)
              child_node = Tree::TreeNode.new(path_component, item)
              parent_node << child_node
              item.id = ReportPortal.start_item(child_node)
            end
          end
          parent_node = child_node
        end
        @feature_node = child_node
      end

      def end_feature(desired_time)
        ReportPortal.finish_item(@feature_node.content, nil, time_to_send(desired_time))
        # Folder items can't be finished here because when the folder started we didn't track
        #   which features the folder contains.
        # It's not easy to do it using Cucumber currently:
        #   https://github.com/cucumber/cucumber-ruby/issues/887
      end

      def close_all_children_of(root_node)
        root_node.postordered_each do |node|
          if !node.is_root? && !node.content.closed
            ReportPortal.finish_item(node.content)
          end
        end
      end

      def step?(test_step)
        !::Cucumber::Formatter::HookQueryVisitor.new(test_step).hook?
      end
    end
  end
end
