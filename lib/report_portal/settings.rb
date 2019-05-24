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
        # for parallel execution only
        'use_standard_logger' => false,
        'launch_id' => false,
        'file_with_launch_id' => false,
        'launch_uuid'=>true #used when multiple cucumber processes executed 
      }

      keys.each do |key, is_required|
        define_singleton_method(key.to_sym) { setting(key) }
        fail "ReportPortal: Define environment variable '#{PREFIX}#{key}' or key #{key} in the configuration YAML file" if is_required && public_send(key).nil?
      end
      launch_uuid = SecureRandom.uuid unless launch_uuid
    end

    def launch_mode
      is_debug ? 'DEBUG' : 'DEFAULT'
    end

    def file_with_launch_id=(val)
      @file_with_launch_id = val
    end

    def file_with_launch_id
      @file_with_launch_id
    end

    def formatter_modes
      setting('formatter_modes') || []
    end

    def project_url
      "#{endpoint}/#{project}"
    end

    private

    def setting(key)
      pkey = PREFIX + key
      ENV.key?(pkey) ? YAML.load(ENV[pkey]) : @properties[key]
    end
  end
end
