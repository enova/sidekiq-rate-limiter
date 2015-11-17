require 'spec_helper'
require 'sidekiq'
require 'sidekiq/api'

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

  let(:options)       { { queues: [queue, another_queue, another_queue] } }
  let(:queue)         { 'basic' }
  let(:another_queue) { 'some_other_queue' }
  let(:args)          { ['I am some args'] }
  let(:worker)        { Job }
  let(:proc_worker)   { ProcJob }
  let(:redis_class)   { Sidekiq.redis { |conn| conn.class } }

  it 'should inherit from Sidekiq::BasicFetch' do
    described_class.should < Sidekiq::BasicFetch
  end

  it 'should retrieve work with strict setting' do
    fetch = described_class.new options.merge(:strict => true)
    fetch.queues_cmd.should eql(["queue:#{queue}", "queue:#{another_queue}", Sidekiq::BasicFetch::TIMEOUT])
  end

  it 'should retrieve work', queuing: true do
    worker.perform_async(*args)
    fetch   = described_class.new(options)
    work    = fetch.retrieve_work
    parsed  = JSON.parse(work.job)

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

  it 'should accept procs for limit, name, and period config keys', queuing: true do
    proc_worker.perform_async(1,2)

    Sidekiq::RateLimiter::Limit.should_receive(:new).with(anything(), {:limit => 2, :interval => 2, :name => "2"}).and_call_original

    fetch = described_class.new(options)
    work   = fetch.retrieve_work
  end

end
