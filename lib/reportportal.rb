require 'json'
require 'faraday'
require 'uri'
require 'pathname'
require 'tempfile'

require_relative 'report_portal/settings'
require_relative 'report_portal/patches/faraday'

module ReportPortal
  TestItem = Struct.new(:name, :type, :id, :start_time, :description, :closed, :tags)
  LOG_LEVELS = { error: 'ERROR', warn: 'WARN', info: 'INFO', debug: 'DEBUG', trace: 'TRACE', fatal: 'FATAL', unknown: 'UNKNOWN' }
  class << self
    attr_accessor :launch_id, :current_scenario, :last_used_time, :logger
    @verbose = false

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
      @launch_id = process_request('launch', :post, data.to_json)['id']
    end

    def remote_launch
      process_request("launch/#{@launch_id}", :get)
    end

    def update_launch(data)
      process_request("launch/#{@launch_id}/update", :put, data.to_json)
    end

    def finish_launch(end_time = now)
      logger.debug "finish_launch: [#{end_time}]"
      data = { end_time: end_time }
      process_request("launch/#{@launch_id}/finish", :put, data.to_json)
    end

    def start_item(item_node)
      item = item_node.content
      data = { start_time: item.start_time, name: item.name[0, 255], type: item.type.to_s, launch_id: @launch_id, description: item.description }
      data[:tags] = item.tags unless item.tags.empty?
      url = 'item'
      url += "/#{item_node.parent.content.id}" unless item_node.parent && item_node.parent.is_root?
      process_request(url, :post, data.to_json)['id']
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
          response = process_request("item/#{item.id}", :put, data.to_json)
          logger.debug "finish_item: response [#{response}] "
        rescue RestClient::Exception => e
          response = JSON.parse(e.response)

          raise e unless response['error_code'] == 40018
        end
        item.closed = true
      end
    end

    # TODO: implement force finish

    def send_log(status, message, time)
      @logger.debug "send_log: [#{status}],[#{message}], #{@current_scenario} "
      unless @current_scenario.nil? || @current_scenario.closed # it can be nil if scenario outline in expand mode is executed
        data = { item_id: @current_scenario.id, time: time, level: status_to_level(status), message: message.to_s }
        process_request('log', :post, data.to_json)
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
      headers = {'Content-Type': 'multipart/form-data'}
      payload = { :json_request_part => [json].to_json,
                  file_name => Faraday::UploadIO.new(path, mime_type) }
      process_request('log', :post, payload, headers)
    end

    def get_item(name, parent_node)
      if parent_node.is_root? # folder without parent folder
        url = "item?filter.eq.launch=#{@launch_id}&filter.eq.name=#{URI.escape(name)}&filter.size.path=0"
      else
        url = "item?filter.eq.launch=#{@launch_id}&filter.eq.parent=#{parent_node.content.id}&filter.eq.name=#{URI.escape(name)}"
      end
      process_request(url, :get)
    end

    def remote_item(item_id)
      process_request("item/#{item_id}", :get)
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
        response = process_request(url, :get)
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

    private

    def process_request(path, method, *options)
      tries = 5
      begin
        response = rp_client.send(method, path, *options)
      rescue RestClient::Exception => e
        logger.warn("Exception[#{e}],class:[#{e.class}],class:[#{e.class}], retry_count: [#{tries}]")
        logger.error("TRACE[#{e.backtrace}]")
        response = JSON.parse(e.response)
        m = response['message'].match(%r{Start time of child \['(.+)'\] item should be same or later than start time \['(.+)'\] of the parent item\/launch '.+'})
        if m
          parent_time = Time.strptime(m[2], '%a %b %d %H:%M:%S %z %Y')
          data = JSON.parse(options[0])
          logger.warn("RP error : 40025, time of a child: [#{data['start_time']}], paren time: [#{(parent_time.to_f * 1000).to_i}]")
          data['start_time'] = (parent_time.to_f * 1000).to_i + 1000
          options[0] = data.to_json
          ReportPortal.last_used_time = data['start_time']
        else
          logger.error("RestClient::Exception -> response: [#{response}]")
          logger.error("TRACE[#{e.backtrace}]")
          raise
        end

        retry unless (tries -= 1).zero?
      end
      JSON.parse(response.body)
    end

    def rp_client
      @connection ||= Faraday.new(url: Settings.instance.project_url) do |f|
        f.headers = {Authorization: "Bearer #{Settings.instance.uuid}", Accept: 'application/json', 'Content-type': 'application/json'}
        verify_ssl = Settings.instance.disable_ssl_verification
        f.ssl.verify = !verify_ssl unless verify_ssl.nil?
        f.request :multipart
        f.request :url_encoded
        f.adapter :net_http
      end

      @connection
    end
  end
end
