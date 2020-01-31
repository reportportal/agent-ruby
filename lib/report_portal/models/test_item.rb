module ReportPortal
  # Represents a test item
  class TestItem
    attr_reader :launch_id, :unique_id, :name, :description, :type, :parameters, :tags, :status, :start_time
    attr_accessor :id, :closed

    def initialize(options = {})
      options = options.map { |k, v| [k.to_sym, v] }.to_h
      @launch_id = options[:launch_id]
      @unique_id = options[:unique_id]
      @name = options[:name]
      @description = options[:description]
      @type = options[:type]
      @parameters = options[:parameters]
      @tags = options[:tags]
      @status = options[:status]
      @start_time = options[:start_time]
      @id = options[:id]
      @closed = options[:closed]
    end
  end
end
