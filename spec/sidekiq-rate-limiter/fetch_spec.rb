require 'spec_helper'
require 'sidekiq'
require 'sidekiq/api'

RSpec.describe Sidekiq::RateLimiter::Fetch do
  before(:all) do
    class Job
      include Sidekiq::Worker
      sidekiq_options 'queue'    => 'basic',
                      'retry'    => false,
                      'rate' => {
                          'limit'  => 1,
                          'period' => 1
                      }
      def perform(*args); end
    end
    class ProcJob
      include Sidekiq::Worker
      sidekiq_options 'queue'    => 'basic',
                      'retry'    => false,
                      'rate' => {
                          'limit'  => ->(arg1, arg2) { arg2 },
                          'name'   => ->(arg1, arg2) { arg2 },
                          'period' => ->(arg1, arg2) { arg2 }
                      }
      def perform(arg1, arg2); end
    end
  end

  let(:options) do
    if Sidekiq::VERSION =~ /^(4|5|6\.[0-4])/
      { queues: [queue, another_queue, another_queue] }
    elsif Sidekiq::VERSION.start_with?('7.')
      config = Sidekiq.default_configuration
      config.queues = [queue, another_queue, another_queue]
      config.default_capsule
    else
      Sidekiq.tap { |s| s[:queues] = [queue, another_queue, another_queue] }
    end
  end

  let(:queue)         { 'basic' }
  let(:another_queue) { 'some_other_queue' }
  let(:args)          { ['I am some args'] }
  let(:worker)        { Job }
  let(:proc_worker)   { ProcJob }
  let(:redis_class)   { Sidekiq.redis { |conn| conn.class } }

  it 'should inherit from Sidekiq::BasicFetch' do
    expect(described_class).to be < Sidekiq::BasicFetch
  end

  it 'should retrieve work with strict setting' do
    timeout =
      if defined? Sidekiq::BasicFetch::TIMEOUT
        Sidekiq::BasicFetch::TIMEOUT
      else
        Sidekiq::Fetcher::TIMEOUT
      end
    
    if Sidekiq::VERSION.start_with?('6.5.')
      _timeout = { timeout: timeout}
      timeout = _timeout
    end

    if !Sidekiq::VERSION.start_with?('7.')
      options.merge!(strict: true)
    end

    fetch = described_class.new(options)

    expect(fetch.queues_cmd).to eql(["queue:#{queue}", "queue:#{another_queue}", timeout])
  end

  it 'should retrieve work', queuing: true do
    worker.perform_async(*args)
    fetch   = described_class.new(options)
    work    = fetch.retrieve_work
    parsed  = JSON.parse(work.respond_to?(:message) ? work.message : work.job)

    expect(work).not_to be_nil
    expect(work.queue_name).to eql(queue)
    expect(work.acknowledge).to be_nil

    expect(parsed).to include(worker.get_sidekiq_options)
    expect(parsed).to include("class" => worker.to_s, "args" => args)
    expect(parsed).to include("jid", "enqueued_at")

    q = Sidekiq::Queue.new(queue)
    expect(q.size).to eq 0
  end

  it 'should place rate-limited work at the back of the queue', queuing: true do
    worker.perform_async(*args)
    expect_any_instance_of(Sidekiq::RateLimiter::Limit).to receive(:exceeded?).and_return(true)
    expect_any_instance_of(redis_class).to receive(:lpush).exactly(:once).and_call_original

    fetch = described_class.new(options)
    expect(fetch.retrieve_work).to be_nil

    q = Sidekiq::Queue.new(queue)
    expect(q.size).to eq 1
  end

  it 'should accept procs for limit, name, and period config keys', queuing: true do
    proc_worker.perform_async(1,2)

    expect(Sidekiq::RateLimiter::Limit).
      to receive(:new).
      with(anything(), {:limit => 2, :interval => 2, :name => "2"}).
      and_call_original

    fetch = described_class.new(options)
    work   = fetch.retrieve_work
  end

end
