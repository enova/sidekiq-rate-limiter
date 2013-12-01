require 'spec_helper'

describe Sidekiq::RateLimiter, 'server configuration' do
  before do
    Sidekiq.stub(:server? => true)
    require 'sidekiq-rate-limiter/server'
  end

  it 'should set Sidekiq.options[:fetch] as desired' do
    Sidekiq.configure_server do |config|
      Sidekiq.options[:fetch].should eql(Sidekiq::RateLimiter::Fetch)
    end
  end

  it 'should inherit from Sidekiq::BasicFetch' do
    Sidekiq.configure_server do |config|
      Sidekiq.options[:fetch].should < Sidekiq::BasicFetch
    end
  end
end
