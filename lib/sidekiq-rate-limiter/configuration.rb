module Sidekiq::RateLimiter
  class Configuration
    attr_accessor :fetch_strategy

    def initialize
      @fetch_strategy = Sidekiq::RateLimiter::BasicStrategy
    end
  end
end
