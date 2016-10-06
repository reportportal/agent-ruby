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
  fail 'Failure in before hook'
end

After('@fail_after') do
  fail 'Failure in after hook'
end

Before do
  puts 'in before hook'
end

After do
  puts 'in after hook'
end

AfterStep do
  if @invoke_after_step
    fail 'I failed!'
  end
end
