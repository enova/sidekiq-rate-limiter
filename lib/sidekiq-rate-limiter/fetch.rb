require 'celluloid'
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
      message = JSON.parse(work.message) rescue {}

      klass      = message['class']
      rate       = message['rate']    || message['throttle'] || {}
      limit      = rate['limit']      || rate['threshold']
      interval   = rate['period']     || rate['interval']
      name       = rate['name']       || DEFAULT_LIMIT_NAME
      per_server = rate['per_server'] || false

      return work unless !!(klass && limit && interval)

      options = {
        :limit      => limit,
        :interval   => interval,
        :name       => name,
        :per_server => per_server
      }

      Sidekiq.redis do |conn|
        lim = Limit.new(conn, options)
        if lim.exceeded?(klass)
          conn.lpush("queue:#{work.queue_name}", work.message)
          nil
        else
          lim.add(klass)
          work
        end
      end
    end
  end

  class Limit < RedisRateLimiter
    def initialize(redis, options = {})
      options = options.dup
      name = options.delete('name') ||
             options.delete(:name)
      scope_by_hostname = options.delete(:per_server)

      super(scope_by_hostname ? "#{hostname}:#{name}" : name, redis, options)
    end

    private

    def hostname
      Socket.gethostname
    end
  end

end
