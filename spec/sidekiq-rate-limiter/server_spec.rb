require 'spec_helper'

RSpec.describe Sidekiq::RateLimiter, 'server configuration' do
  before do
    allow(Sidekiq).to receive(:server?).and_return true
    require 'sidekiq-rate-limiter/server'
  end

  it 'should set Sidekiq.options[:fetch] as desired' do
    Sidekiq.configure_server do |config|
      if Sidekiq::VERSION =~ /^(4|5|6.0)/
        expect(Sidekiq.options[:fetch]).to eql(Sidekiq::RateLimiter::Fetch)
      else
        expect(Sidekiq.options[:fetch]).to be_a(Sidekiq::RateLimiter::Fetch)
      end
    end
  end

  it 'should inherit from Sidekiq::BasicFetch' do
    Sidekiq.configure_server do |config|
      if Sidekiq::VERSION =~ /^(4|5|6.0)/
        expect(Sidekiq.options[:fetch]).to be < Sidekiq::BasicFetch
      else
        expect(Sidekiq.options[:fetch].class.ancestors[1]).to be(Sidekiq::BasicFetch)
      end
    end
  end
end
