require 'bundler'
Bundler::GemHelper.install_tasks

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new
task :default => :spec

desc 'Start IRB with preloaded environment'
task :console do
  exec 'irb', "-I#{File.join(File.dirname(__FILE__), 'lib')}", '-rsidekiq-rate-limiter'
end
