lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'report_portal/version'

Gem::Specification.new do |s|
  s.name                   = 'reportportal'
  s.version                = ReportPortal::VERSION
  s.summary                = 'ReportPortal Ruby Client'
  s.description            = 'Cucumber and RSpec clients for EPAM ReportPortal system'
  s.authors                = ['Aliaksandr Trush', 'Sergey Gvozdyukevich', 'Andrei Botalov']
  s.email                  = 'dzmitry_humianiuk@epam.com'
  s.homepage               = 'https://github.com/reportportal/agent-ruby'
  s.files                  = ['README.md', 'LICENSE', 'LICENSE.LESSER'] + Dir['lib/**/*']
  s.required_ruby_version  = '>= 2.3.0'
  s.license                = 'Apache-2.0'

  s.add_dependency('http', '~> 4.0')
  s.add_dependency('rubytree', '>=0.9.3')

  s.add_development_dependency('rubocop', '0.71')
end
