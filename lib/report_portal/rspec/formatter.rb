require 'securerandom'
require 'tree'
require 'rspec/core'

require_relative '../../reportportal'
require_relative 'report'

# TODO: Screenshots
# TODO: Logs
module ReportPortal
  module RSpec
    class Formatter < Report

      ::RSpec::Core::Formatters.register self, :start, :example_group_started, :example_group_finished,
                                         :example_started, :example_passed, :example_failed,
                                         :example_pending, :message, :stop

      def initialize(_output)
        ENV['REPORT_PORTAL_USED'] = 'true'
      end

      def start(_start_notification)
        cmd_args = ARGV.map { |arg| arg.include?('rp_uuid=') ? 'rp_uuid=[FILTERED]' : arg }.join(' ')
        ReportPortal.start_launch(cmd_args)
        @root_node = Tree::TreeNode.new(SecureRandom.hex)
        @current_group_node = @root_node
      end

      def example_group_finished(_group_notification)
        unless @current_group_node.nil?
          ReportPortal.finish_item(@current_group_node.content)
          @current_group_node = @current_group_node.parent
        end
      end
    end
  end
end
