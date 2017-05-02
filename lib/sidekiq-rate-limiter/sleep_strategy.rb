module Sidekiq::RateLimiter
  class SleepStrategy
    def call(work, klass, args, options)
      Sidekiq.redis do |conn|
        lim = Limit.new(conn, options)
        if lim.exceeded?(klass)
          # if this job is being rate-limited for longer than 1 second, sleep for that amount
          # of time before putting the job back on the queue.
          #
          # This is undesirable as it ties up the sidekiq thread for one second, but it does help in situations where
          # high redis/sidekiq CPU usage is causing problems.

          if lim.retry_in?(klass) > 1.0
            sleep(1)
          end
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
