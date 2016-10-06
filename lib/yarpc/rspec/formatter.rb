# Copyright 2015 EPAM Systems
# 
# 
# This file is part of YARPC.
# 
# YARPC is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# YARPC is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with YARPC.  If not, see <http://www.gnu.org/licenses/>.

require 'securerandom'
require 'tree'
require 'rspec/core'

require_relative '../../yarpc'

# TODO: Screenshots
# TODO: Logs
module YARPC
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
        YARPC.start_launch(cmd_args)
        @root_node = Tree::TreeNode.new(SecureRandom.hex)
        @current_group_node = @root_node
      end

      def example_group_started(group_notification)
        description = group_notification.group.description
        if description.size < MIN_DESCRIPTION_LENGTH
          p "Group description should be at least #{MIN_DESCRIPTION_LENGTH} characters ('group_notification': #{group_notification.inspect})"
          return
        end
        item = YARPC::TestItem.new(description[0..MAX_DESCRIPTION_LENGTH-1],
                                   :TEST,
                                   nil,
                                   YARPC.now,
                                   '',
                                   false,
                                   [])
        group_node = Tree::TreeNode.new(SecureRandom.hex, item)
        if group_node.nil?
          p "Group node is nil for item #{item.inspect}"
        else
          @current_group_node << group_node unless @current_group_node.nil? # make @current_group_node parent of group_node
          @current_group_node = group_node
          group_node.content.id = YARPC.start_item(group_node)
        end
      end

      def example_group_finished(_group_notification)
        unless @current_group_node.nil?
          YARPC.finish_item(@current_group_node.content)
          @current_group_node = @current_group_node.parent
        end
      end

      def example_started(notification)
        description = notification.example.description
        if description.size < MIN_DESCRIPTION_LENGTH
          p "Example description should be at least #{MIN_DESCRIPTION_LENGTH} characters ('notification': #{notification.inspect})"
          return
        end
        YARPC.current_scenario = YARPC::TestItem.new(description[0..MAX_DESCRIPTION_LENGTH-1],
                                                     :STEP,
                                                     nil,
                                                     YARPC.now,
                                                     '',
                                                     false,
                                                     [])
        example_node = Tree::TreeNode.new(SecureRandom.hex, YARPC.current_scenario)
        if example_node.nil?
          p "Example node is nil for scenario #{YARPC.current_scenario.inspect}"
        else
          @current_group_node << example_node
          example_node.content.id = YARPC.start_item(example_node)
        end
      end

      def example_passed(_notification)
        YARPC.finish_item(YARPC.current_scenario, :passed) unless YARPC.current_scenario.nil?
        YARPC.current_scenario = nil
      end

      def example_failed(notification)
        exception = notification.exception
        YARPC.send_log(:failed, %(#{exception.class}: #{exception.message}\n\nStacktrace: #{notification.formatted_backtrace.join("\n")}), YARPC.now)
        YARPC.finish_item(YARPC.current_scenario, :failed) unless YARPC.current_scenario.nil?
        YARPC.current_scenario = nil
      end

      def example_pending(_notification)
        YARPC.finish_item(YARPC.current_scenario, :skipped) unless YARPC.current_scenario.nil?
        YARPC.current_scenario = nil
      end

      def message(notification)
        if notification.message.respond_to?(:read)
          YARPC.send_file(:passed, notification.message)
        else
          YARPC.send_log(:passed, notification.message, YARPC.now)
        end
      end

      def stop(_notification)
        YARPC.finish_launch
      end
    end
  end
end
