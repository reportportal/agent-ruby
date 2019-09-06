require 'cucumber'
require 'pathname'

$odd_even = 0
$odd_even_started = false

After do |scenario|
  $odd_even += 1 if $odd_even_started
  if scenario.failed?
    image = Pathname(__FILE__).dirname.parent.parent + 'assets' + 'crane.png'
    embed image, 'image/png', 'Failure screenshot'
  end
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
