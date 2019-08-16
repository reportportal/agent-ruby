require 'json'
require 'uri'
require 'pathname'
require 'tempfile'
require 'faraday'

require_relative 'report_portal/patches/faraday'
require_relative 'report_portal/settings'
require_relative 'report_portal/client'

module ReportPortal
  TestItem = Struct.new(:name, :type, :id, :start_time, :description, :closed, :tags)
  LOG_LEVELS = { error: 'ERROR', warn: 'WARN', info: 'INFO', debug: 'DEBUG', trace: 'TRACE', fatal: 'FATAL', unknown: 'UNKNOWN' }
  class << self
    attr_accessor :launch_id, :current_scenario, :last_used_time, :logger

    def initialize(logger)
      @logger = logger
      @client = ReportPortal::Client.new(logger)
    end

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
      @launch_id = @client.process_request('launch', :post, data.to_json)['id']
    end

    def remote_launch
      @client.process_request("launch/#{@launch_id}", :get)
    end

    def update_launch(data)
      @client.process_request("launch/#{@launch_id}/update", :put, data.to_json)
    end

    def finish_launch(end_time = now)
      logger.debug "finish_launch: [#{end_time}]"
      data = { end_time: end_time }
      @client.process_request("launch/#{@launch_id}/finish", :put, data.to_json)
    end

    def start_item(item_node)
      item = item_node.content
      data = { start_time: item.start_time, name: item.name[0, 255], type: item.type.to_s, launch_id: @launch_id, description: item.description }
      data[:tags] = item.tags unless item.tags.empty?
      url = 'item'
      url += "/#{item_node.parent.content.id}" unless item_node.parent && item_node.parent.is_root?
      @client.process_request(url, :post, data.to_json)['id']
    end

    def finish_item(item, status = nil, end_time = nil, force_issue = nil)
      if item.nil? || item.id.nil? || item.closed
        logger.debug 'finish_item: Item details are missing or already closed'
      else
        data = { end_time: end_time.nil? ? now : end_time }
        data[:status] = status unless status.nil?
        if force_issue && status != :passed # TODO: check for :passed status is probably not needed
          data[:issue] = { issue_type: 'AUTOMATION_BUG', comment: force_issue.to_s }
        elsif status == :skipped
          data[:issue] = { issue_type: 'NOT_ISSUE' }
        end
        logger.debug "finish_item:id[#{item}], data: #{data} "
        begin
          response = @client.process_request("item/#{item.id}", :put, data.to_json)
          logger.debug "finish_item: response [#{response}] "
        rescue RestClient::Exception => e
          response = JSON.parse(e.response)
          raise e unless response['error_code'] == 40_018
        end
        item.closed = true
      end
    end

    # TODO: implement force finish

    def send_log(status, message, time)
      @logger.debug "send_log: [#{status}],[#{message}], #{@current_scenario} "
      unless @current_scenario.nil? || @current_scenario.closed # it can be nil if scenario outline in expand mode is executed
        data = { item_id: @current_scenario.id, time: time, level: status_to_level(status), message: message.to_s }
        @client.process_request('log', :post, data.to_json)
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
      file_name = File.basename(path)
      label ||= file_name
      json = { level: status_to_level(status),
               message: label,
               item_id: @current_scenario.id,
               time: time,
               file: { name: file_name.to_s },
               "Content-Type": 'application/json' }
      payload = { 'json_request_part': [json].to_json,
                  file_name => Faraday::UploadIO.new(path, mime_type) }
      @client.process_request('log', :post, payload, content_type: 'multipart/form-data')
    end

    def get_item(name, parent_node)
      if parent_node.is_root? # folder without parent folder
        url = "item?filter.eq.launch=#{@launch_id}&filter.eq.name=#{URI.escape(name)}&filter.size.path=0"
      else
        url = "item?filter.eq.launch=#{@launch_id}&filter.eq.parent=#{parent_node.content.id}&filter.eq.name=#{URI.escape(name)}"
      end
      @client.process_request(url, :get)
    end

    def remote_item(item_id)
      @client.process_request("item/#{item_id}", :get)
    end

    def item_id_of(name, parent_node)
      data = get_item(name, parent_node)
      if data.key? 'content'
        data['content'].empty? ? nil : data['content'][0]['id']
      else
        nil # item isn't started yet
      end
    end

    def close_child_items(parent_id)
      logger.debug "closing child items: #{parent_id} "
      if parent_id.nil?
        url = "item?filter.eq.launch=#{@launch_id}&filter.size.path=0&page.page=1&page.size=100"
      else
        url = "item?filter.eq.launch=#{@launch_id}&filter.eq.parent=#{parent_id}&page.page=1&page.size=100"
      end
      ids = []
      loop do
        response = @client.process_request(url, :get)
        if response.key?('links')
          link = response['links'].find { |i| i['rel'] == 'next' }
          url = link.nil? ? nil : link['href']
        else
          url = nil
        end
        response['content'].each do |i|
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
  end
end
