require 'sidekiq'
require 'sidekiq/testing'
require 'pry-byebug'

## Configuring sidekiq
options = {
  logger: nil,
  redis: { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
}

Sidekiq.configure_client do |config|
  options.each do |option, value|
    config.send("#{option}=", value)
  end
end

Sidekiq.configure_server do |config|
  options.each do |option, value|
    config.send("#{option}=", value)
  end
end


## Code Coverage
require 'simplecov'

SimpleCov.start do
  if ENV['CI']
    require 'simplecov-lcov'

    SimpleCov::Formatter::LcovFormatter.config do |c|
      c.report_with_single_file = true
      c.single_report_path = 'coverage/lcov.info'
    end

    formatter SimpleCov::Formatter::LcovFormatter
  end

  add_filter %w[version.rb spec/]
end

require File.expand_path("../../lib/sidekiq-rate-limiter", __FILE__)

## Hook to set Sidekiq::Testing mode using rspec tags
RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expose_current_running_example_as :example

  config.before(:each) do
    ## Use metadata to determine testing behavior
    ## for queuing.

    case example.metadata[:queuing].to_s
    when 'enable', 'enabled', 'on', 'true'
      Sidekiq::Testing.disable!
    when 'fake', 'mock'
      Sidekiq::Testing.fake!
    when 'inline'
      Sidekiq::Testing.inline!
    else
      defined?(Redis::Connection::Memory) ?
        Sidekiq::Testing.disable! : Sidekiq::Testing.inline!
    end

    if Sidekiq::Testing.disabled?
      Sidekiq.redis { |conn| conn.flushdb }
    elsif Sidekiq::Testing.fake?
      Sidekiq::Worker.clear_all
    end
  end
end
