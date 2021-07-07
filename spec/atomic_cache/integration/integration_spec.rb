# frozen_string_literal: true

require 'spec_helper'

describe 'Integration -' do
  let(:key_storage) { AtomicCache::Storage::SharedMemory.new }
  let(:cache_storage) { AtomicCache::Storage::SharedMemory.new }
  let(:keyspace) { AtomicCache::Keyspace.new(namespace: 'int.waiting') }
  let(:timestamp_manager) { AtomicCache::LastModTimeKeyManager.new(keyspace: keyspace, storage: key_storage) }

  before(:each) do
    key_storage.reset
    cache_storage.reset
  end

  describe 'fallback:' do
    let(:generating_client) { AtomicCache::AtomicCacheClient.new(storage: cache_storage, timestamp_manager: timestamp_manager) }
    let(:fallback_client) { AtomicCache::AtomicCacheClient.new(storage: cache_storage, timestamp_manager: timestamp_manager) }

    it 'falls back to the old value when a lock is present' do
      old_time = Time.local(2021, 1, 1, 15, 30, 0)
      new_time = Time.local(2021, 1, 1, 16, 30, 0)

      # prime cache with an old value

      Timecop.freeze(old_time) do
        generating_client.fetch(keyspace) { "old value" }
      end
      timestamp_manager.last_modified_time = new_time

      # start generating process for new time
      generating_thread = ClientThread.new(generating_client, keyspace)
      generating_thread.start
      sleep 0.05

      value = fallback_client.fetch(keyspace)
      generating_thread.terminate

      expect(value).to eq("old value")
    end
  end

  describe 'waiting:' do
    let(:generating_client) { AtomicCache::AtomicCacheClient.new(storage: cache_storage, timestamp_manager: timestamp_manager) }
    let(:waiting_client) { AtomicCache::AtomicCacheClient.new(storage: cache_storage, timestamp_manager: timestamp_manager) }

    it 'waits for a key when no last know value is available' do
      generating_thread = ClientThread.new(generating_client, keyspace)
      generating_thread.start
      waiting_thread = ClientThread.new(waiting_client, keyspace)
      waiting_thread.start

      generating_thread.generate
      sleep 0.05
      waiting_thread.fetch
      sleep 0.05
      generating_thread.complete
      sleep 0.05

      generating_thread.terminate
      waiting_thread.terminate

      expect(generating_thread.result).to eq([1, 2, 3])
      expect(waiting_thread.result).to eq([1, 2, 3])
    end
  end
end


# Avert your eyes:
# this class allows atomic client interaction to happen asynchronously so that
# the waiting behavior of the client can be tested simultaneous to controlling how
# long the 'generate' behavior takes
#
# It works by accepting an incoming 'message' which it places onto one of two queues
class ClientThread
  attr_reader :result

  # idea: maybe make the return value set when the thread is initialized
  def initialize(client, keyspace)
    @keyspace = keyspace
    @client = client
    @msg_queue = Queue.new
    @generate_queue = Queue.new
    @result = nil
  end

  def start
    @thread = Thread.new(&method(:run))
  end

  def fetch
    @msg_queue << :fetch
  end

  def generate
    @msg_queue << :generate
  end

  def complete
    @generate_queue << :complete
  end

  def terminate
    @msg_queue << :terminate
  end

  private

  def run
    loop do
      msg = @msg_queue.pop
      sleep 0.001; next unless msg

      case msg
      when :terminate
        Thread.stop
      when :generate
        do_generate
      when :fetch
        @result = @client.fetch(@keyspace)
      end
    end
  end

  def do_generate
    @client.fetch(@keyspace) do
      loop do
        msg = @generate_queue.pop
        sleep 0.001; next unless msg
        break if msg == :complete
      end
      @result = [1, 2, 3] # generated value
      @result
    end
  end
end