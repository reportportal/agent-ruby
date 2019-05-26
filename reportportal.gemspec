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

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'report_portal/version'

Gem::Specification.new do |s|
  s.name                   = 'reportportal'
  s.version                = "#{ReportPortal::VERSION}.2"
  s.summary                = 'ReportPortal Ruby Client'
  s.description            = 'Cucumber and RSpec clients for EPAM ReportPortal system'
  s.authors                = ['Aliaksandr Trush', 'Sergey Gvozdyukevich', 'Andrei Botalov']
  s.email                  = 'dzmitry_humianiuk@epam.com'
  s.homepage               = 'https://github.com/reportportal/agent-ruby'
  s.files                  = ['README.md', 'LICENSE', 'LICENSE.LESSER'] + Dir['lib/**/*']
  s.required_ruby_version  = '>= 1.9.3'
  s.license                = 'LGPL-3.0'

  s.add_dependency('rest-client', '~> 2.0')
  s.add_dependency('rubytree', '>=0.9.3')
end
