# Copyright 2015 EPAM Systems
# 
# 
# This file is part of Report Portal.
# 
# Report Portal is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# ReportPortal is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with Report Portal.  If not, see <http://www.gnu.org/licenses/>.

Object.send(:remove_const, :Warning) if Object.const_defined?(:Warning)
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
      end

      def start(_start_notification)
        cmd_args = ARGV.map { |arg| (arg.include? 'rp_uuid=')? 'rp_uuid=[FILTERED]' : arg }.join(' ')
        ReportPortal.start_launch(cmd_args)
        @root_node = Tree::TreeNode.new(SecureRandom.hex)
        @current_group_node = @root_node
      end

      def example_group_started(group_notification)
        description = group_notification.group.description
        if description.size < MIN_DESCRIPTION_LENGTH
          p "Group description should be at least #{MIN_DESCRIPTION_LENGTH} characters ('group_notification': #{group_notification.inspect})"
          return
        end
        item = ReportPortal::TestItem.new(description[0..MAX_DESCRIPTION_LENGTH-1],
                                          :TEST,
                                          nil,
                                          ReportPortal.now,
                                          '',
                                          false,
                                          [])
        group_node = Tree::TreeNode.new(SecureRandom.hex, item)
        if group_node.nil?
          p "Group node is nil for item #{item.inspect}"
        else
          @current_group_node << group_node unless @current_group_node.nil? # make @current_group_node parent of group_node
          @current_group_node = group_node
          group_node.content.id = ReportPortal.start_item(group_node)
        end
      end

      def example_group_finished(_group_notification)
        unless @current_group_node.nil?
          ReportPortal.finish_item(@current_group_node.content)
          @current_group_node = @current_group_node.parent
        end
      end

      def example_started(notification)
        description = notification.example.description
        if description.size < MIN_DESCRIPTION_LENGTH
          p "Example description should be at least #{MIN_DESCRIPTION_LENGTH} characters ('notification': #{notification.inspect})"
          return
        end
        ReportPortal.current_scenario = ReportPortal::TestItem.new(description[0..MAX_DESCRIPTION_LENGTH-1],
                                                                   :STEP,
                                                                   nil,
                                                                   ReportPortal.now,
                                                                   '',
                                                                   false,
                                                                   [])
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
