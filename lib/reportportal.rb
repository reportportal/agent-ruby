require 'base64'
require 'cgi'
require 'http'
require 'json'
require 'mime/types'
require 'pathname'
require 'tempfile'
require 'uri'

require_relative 'report_portal/event_bus'
require_relative 'report_portal/models/item_search_options'
require_relative 'report_portal/models/test_item'
require_relative 'report_portal/settings'
require_relative 'report_portal/http_client'

module ReportPortal
  LOG_LEVELS = { error: 'ERROR', warn: 'WARN', info: 'INFO', debug: 'DEBUG', trace: 'TRACE', fatal: 'FATAL', unknown: 'UNKNOWN' }.freeze

  class << self
    attr_accessor :launch_id, :current_scenario

    def now
      (current_time.to_f * 1000).to_i
    end

    def status_to_level(status)
      case status
      when :passed
        LOG_LEVELS[:info]
      when :failed, :undefined, :pending, :error
        LOG_LEVELS[:error]
      when :skipped
        LOG_LEVELS[:warn]
      else
        LOG_LEVELS.fetch(status, LOG_LEVELS[:info])
      end
    end

    def start_launch(description, start_time = now)
      data = { name: Settings.instance.launch, start_time: start_time, tags: Settings.instance.tags, description: description, mode: Settings.instance.launch_mode }
      @launch_id = send_request(:post, 'launch', json: data)['id']
    end

    def finish_launch(end_time = now)
      data = { end_time: end_time }
      send_request(:put, "launch/#{@launch_id}/finish", json: data)
    end

    def start_item(item_node)
      path = 'item'
      path += "/#{item_node.parent.content.id}" unless item_node.parent&.is_root?
      item = item_node.content
      data = { start_time: item.start_time, name: item.name[0, 255], type: item.type.to_s, launch_id: @launch_id, description: item.description }
      data[:tags] = item.tags unless item.tags.empty?
      event_bus.broadcast(:prepare_start_item_request, request_data: data)
      send_request(:post, path, json: data)['id']
    end

    def finish_item(item, status = nil, end_time = nil, force_issue = nil)
      unless item.nil? || item.id.nil? || item.closed
        data = { end_time: end_time.nil? ? now : end_time }
        data[:status] = status unless status.nil?
        if force_issue && status != :passed # TODO: check for :passed status is probably not needed
          data[:issue] = { issue_type: 'AUTOMATION_BUG', comment: force_issue.to_s }
        elsif status == :skipped
          data[:issue] = { issue_type: 'NOT_ISSUE' }
        end
        send_request(:put, "item/#{item.id}", json: data)
        item.closed = true
      end
    end

    # TODO: implement force finish

    def send_log(status, message, time)
      unless @current_scenario.nil? || @current_scenario.closed # it can be nil if scenario outline in expand mode is executed
        data = { item_id: @current_scenario.id, time: time, level: status_to_level(status), message: message.to_s }
        send_request(:post, 'log', json: data)
      end
    end

    def send_file(status, path_or_src, label = nil, time = now, mime_type = 'image/png')
      str_without_nils = path_or_src.to_s.gsub("\0", '') # file? does not allow NULLs inside the string
      if File.file?(str_without_nils)
        send_file_from_path(status, path_or_src, label, time)
      else
        if mime_type =~ /;base64$/
          mime_type = mime_type[0..-8]
          path_or_src = Base64.decode64(path_or_src)
        end
        extension = ".#{MIME::Types[mime_type].first.extensions.first}"
        Tempfile.open(['report_portal', extension]) do |tempfile|
          tempfile.binmode
          tempfile.write(path_or_src)
          tempfile.rewind
          send_file_from_path(status, tempfile.path, label, time)
        end
      end
    end

    # @option options [Hash] options, see ReportPortal::ItemSearchOptions
    def get_items(filter_options = {})
      page_size = 100
      max_pages = 100
      all_items = []
      1.step.each do |page_number|
        raise 'Too many pages with the results were returned' if page_number > max_pages

        options = ItemSearchOptions.new({ page_size: page_size, page_number: page_number }.merge(filter_options))
        page_items = send_request(:get, 'item', params: options.query_params)['content'].map do |item_params|
          TestItem.new(item_params)
        end
        all_items += page_items
        break if page_items.size < page_size
      end
      all_items
    end

    # @param item_ids [Array<String>] an array of items to remove (represented by ids)
    def delete_items(item_ids)
      send_request(:delete, 'item', params: { ids: item_ids })
    end

    # needed for parallel formatter
    def item_id_of(name, parent_node)
      path = if parent_node.is_root? # folder without parent folder
               "item?filter.eq.launch=#{@launch_id}&filter.eq.name=#{CGI.escape(name)}&filter.size.path=0"
             else
               "item?filter.eq.parent=#{parent_node.content.id}&filter.eq.name=#{CGI.escape(name)}"
             end
      data = send_request(:get, path)
      if data.key? 'content'
        data['content'].empty? ? nil : data['content'][0]['id']
      end
    end

    # needed for parallel formatter
    def close_child_items(parent_id)
      path = if parent_id.nil?
               "item?filter.eq.launch=#{@launch_id}&filter.size.path=0&page.page=1&page.size=100"
             else
               "item?filter.eq.parent=#{parent_id}&page.page=1&page.size=100"
             end
      ids = []
      loop do
        data = send_request(:get, path)
        if data.key?('links')
          link = data['links'].find { |i| i['rel'] == 'next' }
          url = link.nil? ? nil : link['href']
        else
          url = nil
        end
        data['content'].each do |i|
          ids << i['id'] if i['has_childs'] && i['status'] == 'IN_PROGRESS'
        end
        break if url.nil?
      end

      ids.each do |id|
        close_child_items(id)
        finish_item(TestItem.new(id: id))
      end
    end

    # Registers an event. The proc will be called back with the event object.
    def on_event(name, &proc)
      event_bus.on(name, &proc)
    end

    private

    def send_file_from_path(status, path, label, time)
      File.open(File.realpath(path), 'rb') do |file|
        filename = File.basename(file)
        json = [{ level: status_to_level(status), message: label || filename, item_id: @current_scenario.id, time: time, file: { name: filename } }]
        form = {
          json_request_part: HTTP::FormData::Part.new(JSON.dump(json), content_type: 'application/json'),
          binary_part: HTTP::FormData::File.new(file, filename: filename)
        }
        send_request(:post, 'log', form: form)
      end
    end

    def send_request(verb, path, options = {})
      http_client.send_request(verb, path, options)
    end

    def http_client
      @http_client ||= HttpClient.new
    end

    def current_time
      # `now_without_mock_time` is provided by Timecop and returns a real, not mocked time
      return Time.now_without_mock_time if Time.respond_to?(:now_without_mock_time)

      Time.now
    end

    def event_bus
      @event_bus ||= EventBus.new
    end
  end
end
