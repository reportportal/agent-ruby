require 'rake'
require 'pathname'
require 'tempfile'
require_relative '../reportportal'

namespace :reportportal do
  desc 'Start launch in Report Portal and print its id to $stdout (needed for use with ReportPortal::Cucumber::AttachToLaunchFormatter)'
  task :start_launch do
    description = ENV['description']
    file_to_write_launch_id = ENV.fetch('file_for_launch_id') { Pathname(Dir.tmpdir) + 'rp_launch_id.tmp' }
    launch_id = ReportPortal.start_launch(description)
    File.write(file_to_write_launch_id, launch_id)
    puts launch_id
  end

  desc 'Finish launch in Report Portal (needed for use with ReportPortal::Cucumber::AttachToLaunchFormatter)'
  task :finish_launch do
    launch_id = ENV['launch_id']
    file_with_launch_id = ENV['file_with_launch_id']
    puts "Launch id isn't provided. Provide it either via launch_id or file_with_launch_id environment variables" if !launch_id && !file_with_launch_id
    puts "Both launch_id and file_with_launch_id are present in environment variables" if launch_id && file_with_launch_id
    ReportPortal.launch_id = launch_id || File.read(file_with_launch_id)
    ReportPortal.close_child_items(nil)
    ReportPortal.finish_launch
  end
end
