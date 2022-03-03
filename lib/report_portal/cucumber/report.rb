require 'cucumber/formatter/io'
require 'tree'
require 'securerandom'

require_relative '../../reportportal'
require_relative '../logging/logger'

module ReportPortal
  module Cucumber
    # @api private
    class Report
      def parallel?
        false
      end

      def attach_to_launch?
        ReportPortal::Settings.instance.formatter_modes.include?('attach_to_launch')
      end

      def initialize(extractor)
        @extractor = extractor
        @last_used_time = 0
        @root_node = Tree::TreeNode.new('')
        @parent_item_node = @root_node
        start_launch
      end

      def start_launch(desired_time = ReportPortal.now)
        if attach_to_launch?
          ReportPortal.launch_id =
            if ReportPortal::Settings.instance.launch_id
              ReportPortal::Settings.instance.launch_id
            else
              file_path = ReportPortal::Settings.instance.file_with_launch_id || (Pathname(Dir.tmpdir) + 'rp_launch_id.tmp')
              File.read(file_path)
            end
          $stdout.puts "Attaching to launch #{ReportPortal.launch_id}"
        else
          description = ReportPortal::Settings.instance.description
          description ||= ARGV.map { |arg| arg.gsub(/rp_uuid=.+/, 'rp_uuid=[FILTERED]') }.join(' ')
          ReportPortal.start_launch(description, time_to_send(desired_time))
        end
      end

      # TODO: time should be a required argument
      def test_case_started(event, desired_time = ReportPortal.now)
        test_case = event.test_case
        feature = @extractor.feature(test_case)
        if report_hierarchy? && !@extractor.same_feature_as_previous_test_case?(@parent_item_node.name, feature)
          end_feature(desired_time) unless @parent_item_node.is_root?
          start_feature_with_parentage(feature, desired_time)
        end

        name = "#{@extractor.scenario_keyword(test_case)}: #{@extractor.scenario_name(test_case)}"
        description = test_case.location.to_s
        tags = test_case.tags.map(&:name)
        type = :STEP

        ReportPortal.current_scenario = ReportPortal::TestItem.new(name: name, type: type, id: nil, start_time: time_to_send(desired_time), description: description, closed: false, tags: tags)
        scenario_node = Tree::TreeNode.new(SecureRandom.hex, ReportPortal.current_scenario)
        @parent_item_node << scenario_node
        ReportPortal.current_scenario.id = ReportPortal.start_item(scenario_node)
      end

      def test_case_finished(event, desired_time = ReportPortal.now)
        result = event.result
        status = result.to_sym
        issue = nil
        if %i[undefined pending].include?(status)
          status = :failed
          issue = result.message
        end
        ReportPortal.finish_item(ReportPortal.current_scenario, status, time_to_send(desired_time), issue)
        ReportPortal.current_scenario = nil
      end

      def test_step_started(event, desired_time = ReportPortal.now)
        test_step = event.test_step
        if @extractor.step?(test_step) # `after_test_step` is also invoked for hooks
          step_source = @extractor.step_source(test_step)
          message = "-- #{step_source.keyword}#{step_source.text} --"
          multiline_arg = @extractor.step_multiline_arg(test_step)
          if multiline_arg.doc_string?
            message << %(\n"""\n#{multiline_arg.content}\n""")
          elsif multiline_arg.data_table?
            message << multiline_arg.raw.reduce("\n") { |acc, row| acc << "| #{row.join(' | ')} |\n" }
          end
          ReportPortal.send_log(:trace, message, time_to_send(desired_time))
        end
      end

      def test_step_finished(event, desired_time = ReportPortal.now)
        test_step = event.test_step
        result = event.result
        status = result.to_sym

        if %i[failed pending undefined].include?(status)
          exception_info = if %i[failed pending].include?(status)
                             ex = result.exception
                             format("%s: %s\n  %s", ex.class.name, ex.message, ex.backtrace.join("\n  "))
                           else
                             format("Undefined step: %s:\n%s", test_step.text, @extractor.step_backtrace_line(test_step))
                           end
          ReportPortal.send_log(:error, exception_info, time_to_send(desired_time))
        end

        if status != :passed
          log_level = status == :skipped ? :warn : :error
          step_type = @extractor.step_type(test_step)
          ReportPortal.send_log(log_level, "#{step_type} #{status}", time_to_send(desired_time))
        end
      end

      def test_run_finished(_event, desired_time = ReportPortal.now)
        end_feature(desired_time) unless @parent_item_node.is_root?

        unless attach_to_launch?
          close_all_children_of(@root_node) # Folder items are closed here as they can't be closed after finishing a feature
          time_to_send = time_to_send(desired_time)
          ReportPortal.finish_launch(time_to_send)
        end
      end

      def puts(message, desired_time = ReportPortal.now)
        ReportPortal.send_log(:info, message, time_to_send(desired_time))
      end

      def embed(path_or_src, mime_type, label, desired_time = ReportPortal.now)
        ReportPortal.send_file(:info, path_or_src, label, time_to_send(desired_time), mime_type)
      end

      def attach(path_or_src, mime_type, desired_time = ReportPortal.now)
        # Cucumber > 4 has deprecated the use of puts, and instead wants
        # the use of "log". This in turn calls attach on all formatters
        # with mime-type 'text/x.cucumber.log+plain'
        if mime_type == 'text/x.cucumber.log+plain'
          ReportPortal.send_log(:info, path_or_src, time_to_send(desired_time))
        else
          ReportPortal.send_file(:info, path_or_src, nil, time_to_send(desired_time), mime_type)
        end
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
        if time_to_send <= @last_used_time
          time_to_send = @last_used_time + 1
        end
        @last_used_time = time_to_send
      end

      def start_feature_with_parentage(feature, desired_time)
        parent_node = @root_node
        child_node = nil
        path_components = @extractor.feature_location(feature).split(File::SEPARATOR)
        path_components.each_with_index do |path_component, index|
          child_node = parent_node[path_component]
          unless child_node # if child node was not created yet
            if index < path_components.size - 1
              name = "Folder: #{path_component}"
              description = nil
              tags = []
              type = :SUITE
            else
              name = @extractor.feature_name(feature)
              description = @extractor.feature_location(feature) # TODO: consider adding feature description and comments
              tags = @extractor.feature_tags(feature).map(&:name)
              type = :TEST
            end
            # TODO: multithreading # Parallel formatter always executes scenarios inside the same feature in the same process
            if (parallel? || attach_to_launch?) &&
               index < path_components.size - 1 && # is folder?
               (id_of_created_item = ReportPortal.uuid_of(name, parent_node)) # get id for folder from report portal
              # get child id from other process
              item = ReportPortal::TestItem.new(name: name, type: type, id: id_of_created_item, start_time: time_to_send(desired_time), description: description, closed: false, tags: tags)
              child_node = Tree::TreeNode.new(path_component, item)
              parent_node << child_node
            else
              item = ReportPortal::TestItem.new(name: name, type: type, id: nil, start_time: time_to_send(desired_time), description: description, closed: false, tags: tags)
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
        root_node.postordered_each do |node|
          if !node.is_root? && !node.content.closed
            ReportPortal.finish_item(node.content)
          end
        end
      end

      def report_hierarchy?
        !ReportPortal::Settings.instance.formatter_modes.include?('skip_reporting_hierarchy')
      end
    end
  end
end
