require 'sidekiq/fetch'
require 'redis_rate_limiter'

module Sidekiq::RateLimiter
  DEFAULT_LIMIT_NAME =
    'sidekiq-rate-limit'.freeze unless defined?(DEFAULT_LIMIT_NAME)

  class Fetch < Sidekiq::BasicFetch
    def retrieve_work
      limit(super)
    end

    def limit(work)
      message = JSON.parse(work.job) rescue {}

      args      = message['args']
      klass     = message['class']
      rate      = Rate.new(message)

      return work unless !!(klass && rate.valid?)

      limit     = rate.limit
      interval  = rate.interval
      name      = rate.name

      options = {
        :limit    => (limit.respond_to?(:call) ? limit.call(*args) : limit).to_i,
        :interval => (interval.respond_to?(:call) ? interval.call(*args) : interval).to_f,
        :name     => (name.respond_to?(:call) ? name.call(*args) : name).to_s,
      }

      Sidekiq.redis do |conn|
        lim = Limit.new(conn, options)
        if lim.exceeded?(klass)
          conn.lpush("queue:#{work.queue_name}", work.job)
          nil
        else
          lim.add(klass)
          work
        end
      end
    end

  end

  class Rate
    def initialize(message)
      @message = message
    end

    def limit
      rate['limit'] || rate['threshold']
    end

    def interval
      rate['interval'] || rate['period']
    end

    def name
      rate['name'] || DEFAULT_LIMIT_NAME
    end

    def valid?
      !!(limit && interval)
    end

    private

    def rate
      use_server_rate? ? server_rate : client_rate
    end

    def use_server_rate?
      server_rate['limit'] && server_rate['limit'].respond_to?(:call) ||
        server_rate['threshold'] && server_rate['threshold'].respond_to?(:call) ||
        server_rate['period'] && server_rate['period'].respond_to?(:call) ||
        server_rate['interval'] && server_rate['interval'].respond_to?(:call) ||
        server_rate['name'] && server_rate['name'].respond_to?(:call)
    end

    def client_rate
      @client_rate ||= @message['rate'] || @message['throttle'] || {}
    end

    def server_rate
      return @server_rate if @server_rate

      worker_class = @message['class']
      options = Object.const_get(worker_class).get_sidekiq_options rescue {}
      server_rate = options['rate'] || options['throttle'] || {}
      @server_rate = server_rate.stringify_keys
    end
  end

  class Limit < RedisRateLimiter
    def initialize(redis, options = {})
      options = options.dup
      name = options.delete('name') ||
             options.delete(:name)

      super(name, redis, options)
    end
  end

end
