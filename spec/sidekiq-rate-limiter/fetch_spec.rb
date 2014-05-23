require 'spec_helper'
require 'sidekiq'

describe Sidekiq::RateLimiter::Fetch do
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

    class PerServerJob
      include Sidekiq::Worker
      sidekiq_options 'queue'    => 'basic',
                      'retry'    => false,
                      'rate' => {
                          'limit'  => 1,
                          'per_server' => true,
                          'period' => 1
                      }
      def perform(*args); end
    end
  end

  let(:options)       { { queues: [queue, another_queue, another_queue] } }
  let(:queue)         { 'basic' }
  let(:another_queue) { 'some_other_queue' }
  let(:args)          { ['I am some args'] }
  let(:worker)        { Job }
  let(:server_worker) { PerServerJob }
  let(:redis_class)   { Sidekiq.redis { |conn| conn.class } }

  it 'should inherit from Sidekiq::BasicFetch' do
    described_class.should < Sidekiq::BasicFetch
  end

  it 'should retrieve work with strict setting' do
    fetch = described_class.new options.merge(:strict => true)
    fetch.queues_cmd.should eql(["queue:#{queue}", "queue:#{another_queue}", 1])
  end

  it 'should retrieve work', queuing: true do
    worker.perform_async(*args)
    fetch = described_class.new(options)
    work    = fetch.retrieve_work
    parsed  = JSON.parse(work.message)

    work.should_not be_nil
    work.queue_name.should eql(queue)
    work.acknowledge.should be_nil

    parsed.should include(worker.get_sidekiq_options)
    parsed.should include("class" => worker.to_s, "args" => args)
    parsed.should include("jid", "enqueued_at")

    q = Sidekiq::Queue.new(queue)
    q.size.should == 0
  end

  it 'should place rate-limited work at the back of the queue', queuing: true do
    worker.perform_async(*args)
    Sidekiq::RateLimiter::Limit.any_instance.should_receive(:exceeded?).and_return(true)
    redis_class.any_instance.should_receive(:lpush).exactly(:once).and_call_original

    fetch = described_class.new(options)
    fetch.retrieve_work.should be_nil

    q = Sidekiq::Queue.new(queue)
    q.size.should == 1
  end

  it 'should rate-limit work across all hosts by default', queuing: true do
    fetch = described_class.new(options)

    worker.perform_async(*args)
    worker.perform_async(*args)

    fetch.retrieve_work
    fetch.retrieve_work.should be_nil
  end

  it 'should rate-limit work per-host when specified in job options', queuing: true do
    fetch = described_class.new(options)

    server_worker.perform_async(*args)
    server_worker.perform_async(*args)

    fetch.retrieve_work

    Sidekiq::RateLimiter::Limit.any_instance.should_receive(:hostname).and_return('not_this_host')

    work = fetch.retrieve_work
    JSON.parse(work.message)['class'].should eq server_worker.name
  end

end
