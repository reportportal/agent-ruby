require 'base64'
require 'cucumber'
require 'pathname'

file_path = Pathname(__dir__).parent.parent + 'assets' + 'crane.png'

After('@file_via_path') do
  embed file_path, 'image/png', 'Image'
end

After('@file_via_src') do
  src = File.read(file_path, mode: 'rb')
  embed src, 'image/png', 'Image'
end

After('@file_via_base64_src') do
  base64_src = Base64.encode64(File.read(file_path, mode: 'rb'))
  embed base64_src, 'image/png;base64', 'Image'
end

Before('@pass_before') do
  # noop
end

After('@pass_after') do
  # noop
end

Before('@fail_before') do
  raise 'Failure in before hook'
end

After('@fail_after') do
  raise 'Failure in after hook'
end

Before do
  puts 'in before hook'
end

After do
  puts 'in after hook'
end

AfterStep do
  if @invoke_after_step
    raise 'I failed!'
  end
end

AfterConfiguration do |config|
  config.on_event :test_run_started do
    ReportPortal.on_event :prepare_start_item_request do |rp_event|
      rp_event.request_data[:parameters] = [{ key: 'param_name', value: 'param_value' }]
    end
    ReportPortal.on_event :prepare_start_item_request do |rp_event|
      rp_event.request_data[:parameters] << { key: 'param_name2', value: 'param_value2' }
    end
  end
end

at_exit do
  items = ReportPortal.get_items(launch_id: ReportPortal.launch_id, name: 'Scenario Outline: Conditionally passing outline, Examples (#1)')
  raise "Incorrect items: #{items}" if items.size != 1
  raise "Incorrect items: #{items}" if items[0].description != 'tests/features/without_background.feature:108'

  ReportPortal.delete_items(items.map(&:id))
  items = ReportPortal.get_items(launch_id: ReportPortal.launch_id, name: 'Scenario Outline: Conditionally passing outline, Examples (#1)')
  raise 'Item is not deleted' unless items.empty?

  puts 'at_exit hook completed successfully'
end
