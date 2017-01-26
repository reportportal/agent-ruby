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

require 'tree'
require 'cucumber/formatter/io'
require 'securerandom'

require_relative '../../reportportal'
require_relative '../logging/logger'

module ReportPortal
  module Cucumber
    class LegacyFormatter
      include ::Cucumber::Formatter::Io

      def attach_to_launch?
        ReportPortal::Settings.instance.formatter_modes.include?('attach_to_launch')
      end

      def rerun?
        ReportPortal::Settings.instance.formatter_modes.include?('rerun')
      end

      def create_folder_nodes?
        ReportPortal::Settings.instance.formatter_modes.include?('group_by_folder')
      end

      def parallel?
        false
      end

      def initialize(_runtime, path_or_io, options)
        ENV['REPORT_PORTAL_USED'] = 'true'

        @io = ensure_io(path_or_io)

        @root_path = File.absolute_path('.') + File::SEPARATOR
        @args = options.expanded_args_without_drb.map { |arg| arg.gsub(/rp_uuid=.+/, "rp_uuid=[FILTERED]") }.join(' ')

        ReportPortal.patch_logger if ReportPortal::Settings.instance.use_standard_logger

        @expand_mode = options[:expand]
        # HACK: patch Cucumber a little bit to support correct hook reporting
        if options[:expand]
          ::Cucumber::Ast::TreeWalker.class_eval do
            def visit_expanded_table_row(table_row, &block)
              broadcast(table_row, &block)
            end
          end

          ::Cucumber::Ast::OutlineTable::ExampleRow.class_eval do
            alias_method :orig_accept_expand, :accept_expand
            def accept_expand(visitor)
              if header?
                orig_accept_expand(visitor) # but it is a noop anyway
              else
                visitor.visit_expanded_table_row(self) { orig_accept_expand(visitor) }
              end
            end
          end
        end

        @unfinished_items = []
      end

      def before_features(features)
        create_node_tree(features)

        if attach_to_launch?
          ReportPortal.launch_id =
            if ReportPortal::Settings.instance.launch_id
              ReportPortal::Settings.instance.launch_id
            else
              file_path = ReportPortal::Settings.instance.file_with_launch_id || (Pathname(Dir.tmpdir) + 'rp_launch_id.tmp')
              File.read(file_path)
            end

          p "Attaching to launch #{ReportPortal.launch_id}"
        else
          start_launch
        end
      end

      def after_features(_features)
        return if attach_to_launch?
        finish_launch
      end

      def before_feature(feature)
        @suppress_background_logs = false
        @background_failed = false

        start_item_and_parentage(feature)
      end

      def after_feature(feature)
        fail "Unclosed scenario #{ReportPortal.current_scenario.name} upon completion of feature #{feature.name}" unless ReportPortal.current_scenario.nil?
        node_to_finish = @current_feature_node
        @current_feature_node = nil
        if rerun? || attach_to_launch?
          @unfinished_items << node_to_finish
          return
        end
        ReportPortal.finish_item(node_to_finish.content)
        unless folder_items_may_be_used_else?
          close_parents_of(node_to_finish)
        end
      end

      def before_background(background)
        fail 'Encountered background without a feature! This is a bug.' if @current_feature_node.nil?
        @is_outline = false
        start_scenario(background)
      end

      def after_background(background)
        @background_failed = background.failed?
        finish_scenario(background.failed? ? :failed : :passed)
        # in the first scenario of a feature background logs are suppressed
        @suppress_background_logs = true
      end

      def before_feature_element(feature_element)
        fail 'Encountered orphan feature element! This is a bug.' if @current_feature_node.nil?
        @is_outline = feature_element.is_a? ::Cucumber::Ast::ScenarioOutline
        start_scenario(feature_element) unless @is_outline
        ReportPortal.send_log(:skipped, 'Scenario was skipped due to background failure', ReportPortal.now) if @background_failed
      end

      def after_feature_element(feature_element)
        finish_scenario(@background_failed ? :skipped : transform_status(feature_element.status)) unless @is_outline
      end

      def before_step(step)
        @suppress_background_logs = false if step.instance_variable_get(:@background).nil?
        unless @suppress_background_logs
          ReportPortal.send_log(:passed, format_step_name(step), ReportPortal.now)
        end
      end

      def before_outline_table(_)
        @outline_row_index = 1
      end

      def before_expanded_table_row(table_row)
        before_table_row(table_row)
      end

      def after_expanded_table_row(table_row)
        after_table_row(table_row, true)
      end

      def before_table_row(row)
        if row.is_a?(::Cucumber::Ast::OutlineTable::ExampleRow) && !row.send(:header?)
          start_scenario(row.scenario_outline, @outline_row_index, row.line)
          ReportPortal.send_log(:skipped, 'Scenario Outline was skipped due to background failure', ReportPortal.now) if @background_failed
          # generate fake start times for log messages
          @outline_steps = row.instance_variable_get(:@step_invocations).map do |step|
            @suppress_background_logs = false if step.instance_variable_get(:@background).nil?
            sleep 0.01
            ReportPortal.now
          end
          @outline_row_index += 1
        end
      end

      def after_table_row(row, expand = false)
        if row.is_a?(::Cucumber::Ast::OutlineTable::ExampleRow) && !row.send(:header?)
          @outline_steps.zip(row.instance_variable_get(:@step_invocations)).each do |time, step|
            unless expand || @suppress_background_logs # in expand mode these were already reported
              ReportPortal.send_log(step.status, format_step_name(step), time)
              ReportPortal.send_log(step.status, "STEP #{step.status.to_s.upcase}", time + 1)
            end

            exception = step.exception || step.instance_variable_get(:@reported_exception)
            unless exception.nil?
              # steps of scenario outlines contain correct exception for undefined status in one field and for pending in another!
              @forced_issue = exception.message if [:undefined, :pending].include? step.status
              exception(exception, :failed) unless expand
            end
          end

          # exception() method is not called from hooks of an outline row, so handling it here
          exception = row.instance_variable_get(:@scenario_exception)
          exception(exception, :failed) unless exception.nil?

          finish_scenario(transform_status(row.status))
        end
      end

      def after_step(step)
        # steps of regular scenarios contain correct exception both for pending and undefined statuses
        if [:pending, :undefined].include? step.status
          @forced_issue = step.exception.message
        end
        ReportPortal.send_log(step.status, "STEP #{step.status.to_s.upcase}", ReportPortal.now) if !@suppress_background_logs && (!@is_outline || @expand_mode)
      end

      def puts(message, _ = :info)
        ReportPortal.send_log(:passed, message, ReportPortal.now)
        @io.puts(message)
      end

      def embed(src, mime_type, label)
        ReportPortal.send_file(:failed, src, label, mime_type)
      end

      def exception(exception, _)
        ReportPortal.send_log(:failed, %(#{exception.class}: #{exception.message}\n\nStacktrace: #{exception.backtrace.join("\n")}), ReportPortal.now) unless @suppress_background_logs
      end

      private

      def folder_items_may_be_used_else?
        create_folder_nodes? && (attach_to_launch? || parallel?)
      end

      def split_path(feature)
        if create_folder_nodes?
          transform_path(File.absolute_path(feature.file)).split(File::SEPARATOR).reject(&:empty?)
        else
          [transform_path(File.absolute_path(feature.file))]
        end
      end

      def transform_path(orig_path)
        orig_path.sub(@root_path, '').sub(@root_path.gsub('/', '\\'), '')
      end

      def transform_status(status)
        [:undefined, :pending].include?(status) ? :failed : status
      end

      def decorate(str)
        sep = '-' * 25
        "#{sep}#{str}#{sep}"
      end

      def start_launch
        ReportPortal.start_launch(@args)
      end

      def finish_launch
        if rerun?
          close_items_with_parentage(@unfinished_items)
        end
        ReportPortal.finish_launch
      end

      def start_scenario(feature_element, row = '', line = '')
        case feature_element
        when ::Cucumber::Ast::Scenario
          name = "Scenario: #{feature_element.name}"
          description = transform_path(feature_element.file_colon_line)
          type = :STEP
        when ::Cucumber::Ast::ScenarioOutline
          name = "Scenario Outline: #{feature_element.name} [#{row}]"
          description = "#{transform_path(feature_element.file)}:#{line}"
          type = :STEP
        when ::Cucumber::Ast::Background
          name = "Background: #{feature_element.name}"
          description = transform_path(feature_element.file_colon_line)
          type = :BEFORE_CLASS
        else
          fail "Unexpected feature element: #{feature_element}"
        end
        tags = feature_element.source_tag_names

        ReportPortal.current_scenario = ReportPortal::TestItem.new(name, type, nil, ReportPortal.now, description, nil, tags)
        scenario_node = Tree::TreeNode.new(SecureRandom.hex, ReportPortal.current_scenario) # name must be unique across siblings
        @current_feature_node << scenario_node
        ReportPortal.current_scenario.id = ReportPortal.start_item(scenario_node)
        @forced_issue = nil
      end

      def finish_scenario(status)
        ReportPortal.finish_item(ReportPortal.current_scenario, status, nil, @forced_issue)
        ReportPortal.current_scenario = nil
      end

      def create_node_tree(features)
        @root_node = Tree::TreeNode.new(@root_path)
        features.each do |feature|
          path_components = split_path(feature)
          parent_node = @root_node
          path_components.each_with_index do |path_component, index|
            child_node = parent_node[path_component]
            if child_node
              parent_node = child_node
              next
            end
            if path_components.size - 1 == index
              name = "Feature: #{feature.name}"
              description = transform_path(feature.file)
              tags = feature.source_tag_names
              type = :TEST
            else
              name = "Folder: #{path_component}"
              description = nil
              tags = []
              type = :SUITE
            end
            item = ReportPortal::TestItem.new(name, type, nil, nil, description, nil, tags)
            child_node = Tree::TreeNode.new(path_component, item)
            parent_node << child_node
            parent_node = child_node
          end
        end
      end

      def close_items_with_parentage(items)
        items.each do |item_node|
          ReportPortal.finish_item(item_node.content)
          close_parents_of(item_node)
        end
      end

      def close_parents_of(item_node)
        item_node.parentage.each do |node|
          next if node.is_root? || node.children.any? { |child| !child.content.closed }
          ReportPortal.finish_item(node.content)
          node.content.closed = true
        end
      end

      def start_item_and_parentage(feature)
        path_components = split_path(feature)
        current_node = @root_node
        path_components.each do |path_component|
          current_node = current_node[path_component]
          fail "Trying to reopen already closed node #{path_component}. This is a bug." if current_node.content.closed

          if folder_items_may_be_used_else? && current_node.content.id.nil? && (id_of_created_item = ReportPortal.item_id_of(current_node))
            current_node.content.id = id_of_created_item
            current_node.content.closed = false
          elsif current_node.content.closed.nil? # Is nil only if item wasn't started yet
            current_node.content.start_time = ReportPortal.now
            current_node.content.id = ReportPortal.start_item(current_node)
            current_node.content.closed = false
          end
        end
        @current_feature_node = current_node
      end

      def format_step_name(step)
        name = decorate("#{step.keyword}#{step.name}")
        # HACK: cannot use #multiline_arg method because it returns non-transformed data (with example variable placeholders)
        table = step.instance_variable_get :@multiline_arg
        if table
          if table.is_a? ::Cucumber::Ast::Table
            table.raw.reduce("#{name}\n") { |acc, row| acc << decorate("| #{row.join(' | ')} |") << "\n" }
          else
            name << %(\n"""\n#{table}\n""")
          end
        else
          name
        end
      end
    end
  end
end
