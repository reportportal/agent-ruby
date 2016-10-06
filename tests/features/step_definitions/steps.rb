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
