module Sidekiq::RateLimiter
  class ScheduleInFutureStrategy
    def call(work, klass, args, options)
      Sidekiq.redis do |conn|
        lim = Limit.new(conn, options)
        if lim.exceeded?(klass)
          # Schedule the job to be executed in the future, when we think the rate limit might be back to normal.
          Sidekiq::Client.enqueue_to_in(work.queue_name, lim.retry_in?(klass), Object.const_get(klass), *args)
          nil
        else
          lim.add(klass)
          work
        end
      end
    end
  end
end

