require 'sidekiq'
require 'sidekiq/testing'

## Confirming presence of redis server executable
abort "## `redis-server` not in path" if %x(which redis-server).empty?
redis_dir = "#{File.dirname(__FILE__)}/support/redis"

## Redis configuration
REDIS_CONFIG = <<-CONF
  daemonize yes
  pidfile #{redis_dir}/test.pid
  port 6380
  timeout 300
  save 900 1
  save 300 10
  save 60 10000
  dbfilename test.rdb
  dir #{redis_dir}
  loglevel warning
  logfile stdout
  databases 1
CONF

%x(echo '#{REDIS_CONFIG}' > #{redis_dir}/test.conf)
redis_command = "redis-server #{redis_dir}/test.conf"
%x[ #{redis_command} ]
##

## Configuring sidekiq
options = {
  logger: nil,
  redis: { :url => "redis://localhost:6380/0" }
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
##

## Configuring simplecov
require 'simplecov'

SimpleCov.start do
  add_filter "vendor"
  add_filter "spec"
end

require File.expand_path("../../lib/sidekiq-rate-limiter", __FILE__)
##

## Hook to set Sidekiq::Testing mode using rspec tags
RSpec.configure do |config|
  config.before(:each) do |example|
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

  config.after(:all) do
    ## Stopping Redis
    ps = %x(ps -A -o pid,command | grep '#{redis_command}' | grep -v grep).split($/)
    pids = ps.map { |p| p.split(/\s+/).reject(&:empty?).first.to_i }
    pids.each { |pid| Process.kill("TERM", pid) }

    ## Cleaning up
    sleep 0.1
    %x(rm -rf #{redis_dir}/*)
  end
end
##
