require 'yaml'
require 'singleton'

module ReportPortal
  class Settings
    include Singleton

    def initialize
      filename = ENV.fetch('rp_config') do
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
        # for parallel execution only
        'use_standard_logger' => false,
        'launch_id' => false,
        'file_with_launch_id' => false
      }

      keys.each do |key, is_required|
        define_singleton_method(key.to_sym) { setting(key) }
        next unless is_required && public_send(key).nil?

        env_variable_name = env_variable_name(key)
        raise "ReportPortal: Define environment variable '#{env_variable_name.upcase}', '#{env_variable_name}' "\
          "or key #{key} in the configuration YAML file"
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
      env_variable_name = env_variable_name(key)
      return YAML.safe_load(ENV[env_variable_name.upcase]) if ENV.key?(env_variable_name.upcase)

      return YAML.safe_load(ENV[env_variable_name]) if ENV.key?(env_variable_name)

      @properties[key]
    end

    def env_variable_name(key)
      'rp_' + key
    end
  end
end
