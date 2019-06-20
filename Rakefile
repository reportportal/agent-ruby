lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

# used for testing purposes
require 'report_portal/tasks'
require 'rubocop/rake_task'

RuboCop::RakeTask.new

task default: %w[rubocop test]

task :test do
  # execute tests here, e.g.
  # ruby "test/unittest.rb"
end
