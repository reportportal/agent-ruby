module ReportPortal
  module RSpec
    # @api private
    class Report

      MAX_DESCRIPTION_LENGTH = 255
      MIN_DESCRIPTION_LENGTH = 3
      
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
          @current_group_node << group_node unless @current_group_node.nil? # make @current_group_node parent of group_node
          @current_group_node = group_node
          group_node.content.id = ReportPortal.start_item(group_node)
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
          @current_group_node << example_node
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

      def stop(_notification)
        ReportPortal.finish_launch
      end
    end
  end
end
