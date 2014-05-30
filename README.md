sidekiq-rate-limiter
====================

[![Build Status](https://secure.travis-ci.org/enova/sidekiq-rate-limiter.png)](http://travis-ci.org/enova/sidekiq-rate-limiter)

Redis-backed, per-worker rate limits for job processing.

## Compatibility

sidekiq-rate-limiter is actively tested against MRI versions 2.0.0 and 1.9.3.

sidekiq-rate-limiter works by using a custom fetch class, the class responsible
for pulling work from the queue stored in redis. Consequently you'll want to be
careful about using other gems that use a same strategy, [sidekiq-priority](https://github.com/socialpandas/sidekiq-priority)
being one example.

I've attempted to support the same options as used by [sidekiq-throttler](https://github.com/gevans/sidekiq-throttler). So, if
your worker already looks like this example I lifted from the sidekiq-throttler wiki:

```ruby
class MyWorker
  include Sidekiq::Worker

  sidekiq_options throttle: { threshold: 50, period: 1.hour }

  def perform(user_id)
    # Do some heavy API interactions.
  end
end
```

Then you wouldn't need to change anything. 

## Installation

Add this line to your application's Gemfile:

    gem 'sidekiq-rate-limiter'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sidekiq-rate-limiter

## Configuration

See [server.rb](lib/sidekiq-rate-limiter/server.rb) for an example of how to
configure sidekiq-rate-limiter. Alternatively you can add the following to your
initializer or what-have-you:

```ruby
require 'sidekiq-rate-limiter/server'
```

Or, if you prefer, amend your Gemfile like so:

    gem 'sidekiq-rate-limiter', :require => 'sidekiq-rate-limiter/server'

By default the limiter uses the name 'sidekiq-rate-limiter'. You can define the
constant ```Sidekiq::RateLimiter::DEFAULT_LIMIT_NAME``` prior to requiring to
change this. Alternatively, you can include a 'name' parameter in the configuration
hash included in sidekiq_options

For example, the following:

```ruby
  class Job
    include Sidekiq::Worker

    sidekiq_options :queue => 'some_silly_queue',
                    :rate  => {
                      :name   => 'my_super_awesome_rate_limit',
                      :limit  => 50,
                      :period => 3600, ## An hour
                    }

    def perform(*args)
      ## do stuff
      ## ...
```

The configuration above would result in any jobs beyond the first 50 in a one
hour period being delayed. The server will continue to fetch items from redis, &
will place any items that are beyond the threshold at the back of their queue.

### Dynamic Configuration

The simplest way to set the rate-limiting options (`:name`, `:limit`, and `:period`) is to assign them each a static value (as above). In some cases, you may wish to calculate values for these options for each specific job. You can do this by supplying a `Proc` for any or all of these options.

The `Proc` may receive as its arguments the same values that will be passed to `perform` when the job is finally performed.

```ruby
class Job
  include Sidekiq::Worker

  sidekiq_options :queue => "my_queue",
                  :rate => {
                    :name   => ->(user_id, rate_limit) { user_id },
                    :limit  => ->(user_id, rate_limit) { rate_limit },
                    :period => ->{ Date.today.monday? ? 2.hours : 4.hours }, # can ignore arguments
                  }

  def perform(user_id, rate_limit)
    ## do something
```

**Caveat**: Normally, Sidekiq stores the `sidekiq_options` with the job on your Redis server at the time the job is enqueued, and it is these stored values that are used for rate-limiting. This means that if you deploy a new version of your code with different `sidekiq_options`, the already-queued jobs will continue to behave according to the options that were in place when they were created. When you supply a `Proc` for one or more of your configuration options, your rate-limiting options can no longer be stored in Redis, but must instead be calculated when the job is fetched by your Sidekiq server for potential execution. If your application code changes while a job is in the queue, it may run with different `sidekiq_options` than existed when it was first enqueued.

## Motivation

Sidekiq::Throttler is great for smaller quantities of jobs, but falls down a bit
for larger queues (see [issue #8](https://github.com/gevans/sidekiq-throttler/issues/8)). In addition, jobs that are
limited multiple times are counted as 'processed' each time, so the stats balloon quickly.

## TODO

* While it subclasses instead of monkey patching, setting Sidekiq.options[:fetch]
is still asking for interaction issues. It would be better for this to be directly
in sidekiq or to use some other means to accomplish this goal.

## Contributing

1. Fork
2. Commit
5. Pull Request

## License

MIT. See [LICENSE](LICENSE) for details.
