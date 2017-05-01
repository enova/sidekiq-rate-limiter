require 'spec_helper'

RSpec.describe "#configure" do
  context 'default' do
    it 'should have the basic strategy by default' do
      expect(Sidekiq::RateLimiter.configuration.fetch_strategy).to eq(Sidekiq::RateLimiter::BasicStrategy)
    end
  end

  context 'with a strategy set' do
    before :each do
      Sidekiq::RateLimiter.configure do |config|
        config.fetch_strategy = Sidekiq::RateLimiter::SleepStrategy
      end
    end

    it 'should have the sleep strategy if set' do
      expect(Sidekiq::RateLimiter.configuration.fetch_strategy).to eq(Sidekiq::RateLimiter::SleepStrategy)
    end

    after :each do
      Sidekiq::RateLimiter.reset
    end
  end
end
