require 'sidekiq-rate-limiter/version'
require 'sidekiq-rate-limiter/fetch'

Sidekiq.configure_server do |config|
  # Backwards compatibility for Sidekiq < 6.1.0 (see https://github.com/mperham/sidekiq/pull/4602 for details)
  if (Sidekiq::BasicFetch.respond_to?(:bulk_requeue))
    Sidekiq.options[:fetch] = Sidekiq::RateLimiter::Fetch
  else
    Sidekiq.options[:fetch] = Sidekiq::RateLimiter::Fetch.new(Sidekiq.options)
  end
end
