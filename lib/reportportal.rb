require 'json'
require 'uri'
require 'pathname'
require 'tempfile'
require 'benchmark'

require_relative 'report_portal/settings'
require_relative 'report_portal/http_client'

module ReportPortal
  TestItem = Struct.new(:name, :type, :id, :start_time, :description, :closed, :tags)
  LOG_LEVELS = { error: 'ERROR', warn: 'WARN', info: 'INFO', debug: 'DEBUG', trace: 'TRACE', fatal: 'FATAL', unknown: 'UNKNOWN' }

  class << self
    attr_accessor :launch_id, :current_scenario

    def now
      (Time.now.to_f * 1000).to_i
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
      path += "/#{item_node.parent.content.id}" unless item_node.parent && item_node.parent.is_root?
      item = item_node.content
      data = { start_time: item.start_time, name: item.name[0, 255], type: item.type.to_s, launch_id: @launch_id, description: item.description }
      data[:tags] = item.tags unless item.tags.empty?
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

    def send_file(status, path, label = nil, time = now, mime_type = 'image/png')
      unless File.file?(path)
        if mime_type =~ /;base64$/
          mime_type = mime_type[0..-8]
          path = Base64.decode64(path)
        end
        extension = ".#{MIME::Types[mime_type].first.extensions.first}"
        temp = Tempfile.open(['file', extension])
        temp.binmode
        temp.write(path)
        temp.rewind
        path = temp
      end
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

    # needed for parallel formatter
    def item_id_of(name, parent_node)
      path = if parent_node.is_root? # folder without parent folder
               "item?filter.eq.launch=#{@launch_id}&filter.eq.name=#{URI.escape(name)}&filter.size.path=0"
             else
               "item?filter.eq.parent=#{parent_node.content.id}&filter.eq.name=#{URI.escape(name)}"
             end
      data = send_request(:get, path)
      if data.key? 'content'
        data['content'].empty? ? nil : data['content'][0]['id']
      else
        nil # item isn't started yet
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
        # temporary, we actually only need the id
        finish_item(TestItem.new(nil, nil, id, nil, nil, nil, nil))
      end
    end

    private

    def send_request(verb, path, options = {})
      result = nil
      $time += Benchmark.realtime do
        result = http_client.send_request(verb, path, options)
      end
      result
    end

    def http_client
      @http_client ||= HttpClient.new
    end
  end
end
