When(/^Passing step #(\d+)$/) do |num|
  puts "Step #{num} passed"
end

When(/^Failing step #(\d+)$/) do |num|
  fail "Step #{num} failed"
end

When(/^Passing step with table:$/) do |_table|
  puts 'Step with table passed'
end

When(/^Step that fails on every second execution$/) do
  if $odd_even.odd?
    fail "Step failed at iteration #{$odd_even}"
  else
    puts "Step passed at iteration #{$odd_even}"
  end
  $odd_even_started = true
end

When(/^Pending step #(\d+)$/) do |num|
  pending "Step #{num} is pending"
end

When(/^Step with multiline string$/) do |str|
  puts "Step with multiline string #{str}"
end

When (/^Step with failing AfterStep hook$/) do
  @invoke_after_step = true
end
