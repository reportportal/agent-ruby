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

require 'securerandom'
require 'tree'
require 'rspec/core'
require 'fileutils'
require_relative '../../reportportal'

module ReportPortal
  module RSpec
    class Formatter
      MAX_DESCRIPTION_LENGTH = 255
      MIN_DESCRIPTION_LENGTH = 3

      ::RSpec::Core::Formatters.register self, :dump_summary, :start

      def initialize(_output)
        ENV['REPORT_PORTAL_USED'] = 'true'
      end

      def start(_start_notification)
        # ReportPortal.start_launch('OMRI-TEST-111')
        @root_node = Tree::TreeNode.new(SecureRandom.hex)
        @current_group_node = @root_node
      end

      def dump_summary(notification)
        return unless should_report?(notification)  # Report to RP only if no failures OR if rerun
        example_group_started(notification.examples.first.example_group)
        notification.examples.each do |example|
          example_started(example)
          case example.execution_result.status
          when :passed
            example_passed(example)
          when :failed
            example_failed(example)
          when :pending
            example_pending(example)
          end
        end
        example_group_finished(notification.examples.first.example_group)
        # stop(nil)
      end

      def should_report?(notification)
        failed = notification.examples.select { |example| example.execution_result.status == :failed }
        is_rerun = !ENV['RERUN'].nil?
        failed == 0 || is_rerun
      end

      def example_group_started(group_notification)
        description = group_notification.description
        description = "#{description} (SUBSET = #{ENV['SUBSET']})" if ENV['SUBSET']
        description += ' (SEQUENTAIL)' if ENV['SEQ']
        if description.size < MIN_DESCRIPTION_LENGTH
          p "Group description should be at least #{MIN_DESCRIPTION_LENGTH} characters ('group_notification': #{group_notification.inspect})"
          return
        end
        tags = []
        item = ReportPortal::TestItem.new(description[0..MAX_DESCRIPTION_LENGTH-1],
                                          :TEST,
                                          nil,
                                          ReportPortal.now,
                                          '',
                                          false,
                                          tags,
                                          false)
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
        is_rerun = !ENV['RERUN'].nil?
        description = notification.description

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
                                                                   [],
                                                                   is_rerun)
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
        puts "^ ^ ^ ^ ^ ^  START SCREENSHOT UPLOAD!  ^ ^ ^ ^ ^ ^"
        upload_screenshots(notification)
        puts "^ ^ ^ ^ ^ ^  END SCREENSHOT UPLOAD!  ^ ^ ^ ^ ^ ^"
        log_content = read_log_file_content(notification)
        ReportPortal.send_log(:failed, log_content, ReportPortal.now)
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
        # ReportPortal.finish_launch
      end

      private

      def read_log_file_content(example)
        exception = example.exception
        base_log = "#{exception.class}: #{exception.message}\n\nBacktrace: #{exception.backtrace.join("\n")}"
        if example.file_path.match('(\w+).rb')
          file_name = $1
          file_name = "#{file_name}_#{ENV['SUBSET']}" unless ENV['SUBSET'].nil?
          run_log = "./log/#{file_name}.log"
          rerun_log = "./log/#{file_name}_rerun.log"
          log_content = if File.exists?(run_log)
                          IO.read(run_log)
                        elsif File.exists?(rerun_log)
                          IO.read(rerun_log)
                        else
                          puts "No log files found!!!\nExpected one of these:\n1: #{run_log}\n2: #{rerun_log}"
                        end
          "#{base_log}\n\n* * *  Full Log  * * *\n\n#{log_content}"
        else
          "example file name did not match [#{example.file_name}]\n\n#{base_log}"
        end
      rescue => error
        puts "read_log_file_content failed\n Error: #{error}"
      end

      def upload_screenshots(notification)
        notification.metadata[:screenshot].each do |img|
          file_name = "./log/#{img}.jpg"
          new_file_name = "./log/#{SecureRandom.uuid}.jpg"
          FileUtils.cp(file_name, new_file_name)
          ReportPortal.send_file(:failed, new_file_name, img, ReportPortal.now, 'image/jpg')
          File.delete(new_file_name)
        end
      end
    end
  end
end
