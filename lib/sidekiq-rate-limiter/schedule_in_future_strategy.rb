module Sidekiq::RateLimiter
  class ScheduleInFutureStrategy
    def call(work, klass, args, options)
      Sidekiq.redis do |conn|
        lim = Limit.new(conn, options)
        if lim.exceeded?(klass)

          # add a random amount of jitter that is proportional to the length of time the retry is in the future.
          # this helps us spread out the jobs more evenly, as clumps of jobs on the queue can interfere with normal
          # throughput of non-rate limited jobs. This jitter is additive. It's also useful in cases where we would like
          # to dump thousands of jobs onto the queue and eventually have them delivered.
          retry_in = lim.retry_in?(klass)
          retry_in = retry_in + rand(retry_in/5) if retry_in > 10

          # Schedule the job to be executed in the future, when we think the rate limit might be back to normal.
          Sidekiq::Client.enqueue_to_in(work.queue_name, retry_in, Object.const_get(klass), *args)
          nil
        else
          lim.add(klass)
          work
        end
      end
    end
  end
end

