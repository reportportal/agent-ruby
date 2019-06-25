require 'json'
require 'rest_client'
require 'uri'
require 'pathname'
require 'tempfile'

require_relative 'report_portal/settings'
require_relative 'report_portal/patches/rest_client'

module ReportPortal
  TestItem = Struct.new(:name, :type, :id, :start_time, :description, :closed, :tags)
  LOG_LEVELS = { error: 'ERROR', warn: 'WARN', info: 'INFO', debug: 'DEBUG', trace: 'TRACE', fatal: 'FATAL', unknown: 'UNKNOWN' }

  class << self
    attr_accessor :launch_id, :current_scenario, :last_used_time

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
      response = project_resource['launch'].post(data.to_json)
      @launch_id = JSON.parse(response)['id']
    end

    def remote_launch
      response = project_resource["launch/#{@launch_id}"].get
      JSON.parse(response)
    end

    def update_launch(data)
      project_resource["launch/#{@launch_id}/update"].put(data.to_json)
    end

    def finish_launch(end_time = now)
      data = { end_time: end_time }
      project_resource["launch/#{@launch_id}/finish"].put(data.to_json)
    end

    def start_item(item_node)
      item = item_node.content
      data = { start_time: item.start_time, name: item.name[0, 255], type: item.type.to_s, launch_id: @launch_id, description: item.description }
      data[:tags] = item.tags unless item.tags.empty?
      begin
        url = 'item'
        url += "/#{item_node.parent.content.id}" unless item_node.parent && item_node.parent.is_root?
        response = project_resource[url].post(data.to_json)
      rescue RestClient::Exception => e
        response_message = JSON.parse(e.response)['message']
        m = response_message.match(%r{Start time of child \['(.+)'\] item should be same or later than start time \['(.+)'\] of the parent item\/launch '.+'})
        raise unless m

        time = Time.strptime(m[2], '%a %b %d %H:%M:%S %z %Y')
        data[:start_time] = (time.to_f * 1000).to_i + 1000
        ReportPortal.last_used_time = data[:start_time]
        retry
      end
      JSON.parse(response)['id']
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
        project_resource["item/#{item.id}"].put(data.to_json)
        item.closed = true
      end
    end

    # TODO: implement force finish

    def send_log(status, message, time)
      unless @current_scenario.nil? || @current_scenario.closed # it can be nil if scenario outline in expand mode is executed
        data = { item_id: @current_scenario.id, time: time, level: status_to_level(status), message: message.to_s }
        project_resource['log'].post(data.to_json)
      end
    end

    def send_file(status, path, label = nil, time = now, mime_type = 'image/png')
      unless File.file?(path)
        extension = ".#{MIME::Types[mime_type].first.extensions.first}"
        temp = Tempfile.open(['file', extension])
        temp.binmode
        temp.write(Base64.decode64(path))
        temp.rewind
        path = temp
      end
      File.open(File.realpath(path), 'rb') do |file|
        label ||= File.basename(file)
        json = { level: status_to_level(status), message: label, item_id: @current_scenario.id, time: time, file: { name: File.basename(file) } }
        data = { :json_request_part => [json].to_json, label => file, :multipart => true, :content_type => 'application/json' }
        project_resource['log'].post(data, content_type: 'multipart/form-data')
      end
    end

    # needed for parallel formatter
    def item_id_of(name, parent_node)
      if parent_node.is_root? # folder without parent folder
        url = "item?filter.eq.launch=#{@launch_id}&filter.eq.name=#{URI.escape(name)}&filter.size.path=0"
      else
        url = "item?filter.eq.launch=#{@launch_id}&filter.eq.parent=#{parent_node.content.id}&filter.eq.name=#{URI.escape(name)}"
      end
      data = JSON.parse(project_resource[url].get)
      if data.key? 'content'
        data['content'].empty? ? nil : data['content'][0]['id']
      else
        nil # item isn't started yet
      end
    end

    # needed for parallel formatter
    def close_child_items(parent_id)
      if parent_id.nil?
        url = "item?filter.eq.launch=#{@launch_id}&filter.size.path=0&page.page=1&page.size=100"
      else
        url = "item?filter.eq.launch=#{@launch_id}&filter.eq.parent=#{parent_id}&page.page=1&page.size=100"
      end
      ids = []
      loop do
        response = JSON.parse(project_resource[url].get)
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

    def project_resource
      options = {}
      options[:headers] = {
        :Authorization => "Bearer #{Settings.instance.uuid}",
        content_type: :json
      }
      verify_ssl = Settings.instance.disable_ssl_verification
      options[:verify_ssl] = !verify_ssl unless verify_ssl.nil?
      RestClient::Resource.new(Settings.instance.project_url, options) do |response, request, _, &block|
        raise(::RestClient::Exception.new, response.body) if response.code == 406
        
        unless (200..207).include?(response.code)
          p "ReportPortal API returned #{response}"
          p "Offending request method/URL: #{request.args[:method].upcase} #{request.args[:url]}"
          p "Offending request payload: #{request.args[:payload]}}"
        end
        response.return!(&block)
      end
    end
  end
end
