module ReportPortal
  # Options of a request to search items
  class ItemSearchOptions
    MAPPING = {
      launch_id: 'filter.eq.launch',
      name: 'filter.eq.name',
      description: 'filter.eq.description',
      parameter_key: 'filter.eq.parameters$key',
      parameter_value: 'filter.eq.parameters$value',
      page_size: 'page.size',
      page_number: 'page.page'
    }.freeze

    attr_reader :query_params

    def initialize(params = {})
      @query_params = params.map { |mapping_key, v| [param_name(mapping_key), v] }.to_h
    end

    private

    def param_name(mapping_key)
      MAPPING.fetch(mapping_key) { raise KeyError, "key not found: '#{mapping_key.inspect}'. It should be one of: #{MAPPING.keys}" }
    end
  end
end
