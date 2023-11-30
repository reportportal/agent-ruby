require 'securerandom'
require 'tree'
require 'rspec/core'

require_relative '../../reportportal'

# TODO: Screenshots
# TODO: Logs
module ReportPortal
  module RSpec
    class Formatter
      MAX_DESCRIPTION_LENGTH = 255
      MIN_DESCRIPTION_LENGTH = 3

      ::RSpec::Core::Formatters.register self, :start, :example_group_started, :example_group_finished,
                                         :example_started, :example_passed, :example_failed,
                                         :example_pending, :message, :stop

      def initialize(_output)
        ENV['REPORT_PORTAL_USED'] = 'true'
        @root_node = Tree::TreeNode.new(SecureRandom.hex)
        @parent_item_node = @root_node
        @last_used_time = 0
      end

      def start(_start_notification)
        if ReportPortal::Settings.instance.attach_to_launch?
          ReportPortal.launch_id =
            if ReportPortal::Settings.instance.launch_id
              ReportPortal::Settings.instance.launch_id
            else
              file_path = ReportPortal::Settings.instance.file_with_launch_id || (Pathname(Dir.pwd) + 'rp_launch_id.tmp')
              File.read(file_path)
            end
          $stdout.puts "Attaching to launch #{ReportPortal.launch_id}"
        else
          cmd_args = ARGV.map { |arg| arg.include?('rp_uuid=') ? 'rp_uuid=[FILTERED]' : arg }.join(' ')
          ReportPortal.start_launch(cmd_args)
        end
      end

      def example_group_started(group_notification)
        description = group_notification.group.description
        if description.size < MIN_DESCRIPTION_LENGTH
          p "Group description should be at least #{MIN_DESCRIPTION_LENGTH} characters ('group_notification': #{group_notification.inspect})"
          return
        end
        item = ReportPortal::TestItem.new(name: description[0..MAX_DESCRIPTION_LENGTH - 1],
                                          type: :TEST,
                                          id: nil,
                                          start_time: ReportPortal.now,
                                          description: '',
                                          closed: false,
                                          tags: [])
        group_node = Tree::TreeNode.new(SecureRandom.hex, item)
        if group_node.nil?
          p "Group node is nil for item #{item.inspect}"
        else
          @parent_item_node << group_node unless @parent_item_node.nil? # make @current_group_node parent of group_node
          @parent_item_node = group_node
          group_node.content.id = ReportPortal.start_item(group_node)
        end
      end

      def example_group_finished(_group_notification)
        unless @parent_item_node.nil?
          ReportPortal.finish_item(@parent_item_node.content)
          @parent_item_node = @parent_item_node.parent
        end
      end

      def example_started(notification)
        description = notification.example.description
        if description.size < MIN_DESCRIPTION_LENGTH
          p "Example description should be at least #{MIN_DESCRIPTION_LENGTH} characters ('notification': #{notification.inspect})"
          return
        end
        ReportPortal.current_scenario = ReportPortal::TestItem.new(name: description[0..MAX_DESCRIPTION_LENGTH - 1],
                                                                   type: :STEP,
                                                                   id: nil,
                                                                   start_time: ReportPortal.now,
                                                                   description: '',
                                                                   closed: false,
                                                                   tags: [])
        example_node = Tree::TreeNode.new(SecureRandom.hex, ReportPortal.current_scenario)
        if example_node.nil?
          p "Example node is nil for scenario #{ReportPortal.current_scenario.inspect}"
        else
          @parent_item_node << example_node
          example_node.content.id = ReportPortal.start_item(example_node)
        end
      end

      def example_passed(_notification)
        ReportPortal.finish_item(ReportPortal.current_scenario, :passed) unless ReportPortal.current_scenario.nil?
        ReportPortal.current_scenario = nil
      end

      def example_failed(notification)
        exception = notification.exception
        ReportPortal.send_log(:failed, %(#{exception.class}: #{exception.message}\n\nStacktrace: #{notification.formatted_backtrace.join("\n")}), ReportPortal.now)
        ReportPortal.finish_item(ReportPortal.current_scenario, :failed) unless ReportPortal.current_scenario.nil?
        ReportPortal.current_scenario = nil
      end

      def example_pending(_notification)
        ReportPortal.finish_item(ReportPortal.current_scenario, :skipped) unless ReportPortal.current_scenario.nil?
        ReportPortal.current_scenario = nil
      end

      def message(notification)
        if notification.message.respond_to?(:read)
          ReportPortal.send_file(:passed, notification.message)
        else
          ReportPortal.send_log(:passed, notification.message, ReportPortal.now)
        end
      end

      def example_finished(desired_time)
        ReportPortal.finish_item(@parent_item_node.content, nil, time_to_send(desired_time))
      end

      def close_all_children_of(root_node)
        root_node.postordered_each do |node|
          if !node.is_root? && !node.content.closed
            ReportPortal.finish_item(node.content)
          end
        end
      end

      def stop(_notification, desired_time = ReportPortal.now)
        example_finished(desired_time) unless @parent_item_node.is_root?

        unless ReportPortal::Settings.instance.attach_to_launch?
          close_all_children_of(@root_node) # Folder items are closed here as they can't be closed after finishing a feature
          time_to_send = time_to_send(desired_time)
          ReportPortal.finish_launch(time_to_send)
        end
      end

      def time_to_send(desired_time)
        time_to_send = desired_time
        if time_to_send <= @last_used_time
          time_to_send = @last_used_time + 1
        end
        @last_used_time = time_to_send
      end
    end
  end
end
