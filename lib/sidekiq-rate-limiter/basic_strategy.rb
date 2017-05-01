module Sidekiq::RateLimiter
  class BasicStrategy
    def call(work, klass, options)
      Sidekiq.redis do |conn|
        lim = Limit.new(conn, options)
        if lim.exceeded?(klass)
          conn.lpush("queue:#{work.queue_name}", work.respond_to?(:message) ? work.message : work.job)
          nil
        else
          lim.add(klass)
          work
        end
      end
    end
  end
end
