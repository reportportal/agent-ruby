require 'yaml'
require 'singleton'

module ReportPortal
  class Settings
    include Singleton

    PREFIX = 'rp_'

    def initialize
      filename = ENV.fetch("#{PREFIX}config") do
        glob = Dir.glob('{,.config/,config/}report{,-,_}portal{.yml,.yaml}')
        p "Multiple configuration files found for ReportPortal. Using the first one: #{glob.first}" if glob.size > 1
        glob.first
      end

      @properties = filename.nil? ? {} : YAML.load_file(filename)
      keys = {
        'uuid' => true,
        'endpoint' => true,
        'project' => true,
        'launch' => true,
        'description' => false,
        'tags' => false,
        'is_debug' => false,
        'disable_ssl_verification' => false,
        'use_standard_logger' => false,
        'launch_id' => false,
        'file_with_launch_id' => false,
        'launch_uuid' => false,
        'log_level' => false
      }

      keys.each do |key, is_required|
        define_singleton_method(key.to_sym) { setting(key) }
        fail "ReportPortal: Define environment variable '#{PREFIX}#{key}' or key #{key} in the configuration YAML file" if is_required && public_send(key).nil?
      end
    end

    def launch_mode
      is_debug ? 'DEBUG' : 'DEFAULT'
    end

    def formatter_modes
      setting('formatter_modes') || []
    end

    private

    def setting(key)
      pkey = PREFIX + key
      ENV.key?(pkey) ? YAML.load(ENV[pkey]) : @properties[key]
    end
  end
end
