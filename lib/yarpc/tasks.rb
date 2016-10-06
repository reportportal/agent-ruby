# Copyright 2015 EPAM Systems
# 
# 
# This file is part of YARPC.
# 
# YARPC is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# YARPC is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with YARPC.  If not, see <http://www.gnu.org/licenses/>.

require 'rake'
require 'pathname'
require 'tempfile'
require 'yarpc'

namespace :yarpc do
  desc 'Start launch in Report Portal and print its id to $stdout (needed for use with YARPC::Cucumber::AttachToLaunchFormatter)'
  task :start_launch do
    description = ENV['description']
    file_to_write_launch_id = ENV.fetch('file_for_launch_id') { Pathname(Dir.tmpdir) + 'rp_launch_id.tmp' }
    launch_id = YARPC.start_launch(description)
    File.write(file_to_write_launch_id, launch_id)
    puts launch_id
  end

  desc 'Finish launch in Report Portal (needed for use with YARPC::Cucumber::AttachToLaunchFormatter)'
  task :finish_launch do
    launch_id = ENV['launch_id']
    file_with_launch_id = ENV['file_with_launch_id']
    puts "Launch id isn't provided. Provide it either via launch_id or file_with_launch_id environment variables" if !launch_id && !file_with_launch_id
    puts "Both launch_id and file_with_launch_id are present in environment variables" if launch_id && file_with_launch_id
    YARPC.launch_id = launch_id || File.read(file_with_launch_id)
    YARPC.close_child_items(nil)
    YARPC.finish_launch
  end
end
