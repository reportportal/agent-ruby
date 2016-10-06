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

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'yarpc/version'

Gem::Specification.new do |s|
  s.name                   = 'yarpc'
  s.version                = YARPC::VERSION
  s.date                   = '2016-08-19'
  s.summary                = 'ReportPortal Ruby Client'
  s.description            = 'Cucumber and RSpec clients for EPAM ReportPortal system'
  s.authors                = ['Aliaksandr Trush', 'Sergey Gvozdyukevich', 'Andrei Botalov']
  s.email                  = 'dzmitry_humianiuk@epam.com'
  s.homepage               = 'https://bitbucket.org/ATrush/yarpc/'
  s.files                  = ['README.md', 'COPYING', 'COPYING.LESSER'] + Dir['lib/**/*']
  s.required_ruby_version  = '>= 1.9.3'
  s.license                = 'LGPL'

  s.add_dependency('rest-client', '~> 2.0')
  s.add_dependency('rubytree', '>=0.9.3')
end
