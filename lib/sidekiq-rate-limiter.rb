require 'sidekiq-rate-limiter/version'
require 'sidekiq-rate-limiter/fetch'
require 'sidekiq-rate-limiter/configuration'

module Sidekiq::RateLimiter
  class << self
    attr_writer :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.reset
    @configuration = Configuration.new
  end

  def self.configure
    yield(configuration)
  end

end
