# frozen_string_literal: true

require 'spec_helper'

describe 'AtomicCacheClient' do
  subject { AtomicCache::AtomicCacheClient.new(storage: cache_storage, timestamp_manager: timestamp_manager) }

  let(:formatter) { Proc.new { |time| time.to_i } }
  let(:keyspace) { AtomicCache::Keyspace.new(namespace: ['foo', 'bar'], root: 'bar') }
  let(:key_storage) { AtomicCache::Storage::InstanceMemory.new }
  let(:cache_storage) { AtomicCache::Storage::InstanceMemory.new }

  let(:timestamp_manager) do
    AtomicCache::LastModTimeKeyManager.new(
      keyspace: keyspace,
      storage: key_storage,
      timestamp_formatter: formatter,
    )
  end

  before(:each) do
    AtomicCache::DefaultConfig.reset
  end

  describe '#fetch' do

    context 'when the value is present' do
      before(:each) do
        timestamp_manager.last_modified_time = 1420090000
      end

      it 'returns the cached value' do
        cache_storage.set(timestamp_manager.current_key(keyspace), 'value')
        expect(subject.fetch(keyspace)).to eq('value')
      end

      it 'returns 0 as a cached value' do
        cache_storage.set(timestamp_manager.current_key(keyspace), '0')
        expect(subject.fetch(keyspace)).to eq('0')
      end

      it 'returns empty strings as a cached value' do
        cache_storage.set(timestamp_manager.current_key(keyspace), '')
        expect(subject.fetch(keyspace)).to eq('')
      end
    end

    context 'when the value is NOT present' do
      context 'and when a block is given' do
        context 'and when another thread is NOT generating,' do

          it 'returns the new value' do
            result = subject.fetch(keyspace) { 'value from block' }
            expect(result).to eq('value from block')
          end

          it 'returns the new value when it is an empty string' do
            result = subject.fetch(keyspace) { '' }
            expect(result).to eq('')
          end

          it 'does not store the value if the generator returns nil' do
            # create a fallback value to make sure we don't use the value from the block
            key_storage.set(keyspace.last_known_key_key, 'foo_value')
            cache_storage.set('foo', 'last known value')

            timestamp_manager.promote(keyspace, last_known_key: 'foo', timestamp: Time.now)
            subject.fetch(keyspace) { nil }
            expect(subject.fetch(keyspace)).to eq('last known value')
          end

          it 'unlocks if the generate block returns nil' do
            subject.fetch(keyspace) { nil }
            expect(key_storage.store).to_not have_key(:'foo:bar:lock')
          end

          it 'stores the new value' do
            subject.fetch(keyspace) { 'value from block' }
            expect(subject.fetch(keyspace)).to eq('value from block')
          end

          it 'stores the updated last mod time' do
            time = Time.local(2018, 1, 1, 15, 30, 0)
            timestamp_manager.promote(keyspace, timestamp: (time - 10).to_i, last_known_key: 'lkk')

            Timecop.freeze(time) do
              subject.fetch(keyspace) { 'value from block' }
              lmt = key_storage.read(timestamp_manager.last_modified_time_key)
              expect(lmt).to eq(time.to_i.to_s)
            end
          end

          it 'stores the current key as the last known key' do
            time = Time.local(2018, 1, 1, 15, 30, 0)
            timestamp_manager.promote(keyspace, last_known_key: "test:#{(time - 10).to_i}", timestamp: time.to_i)

            Timecop.freeze(time) do
              subject.fetch(keyspace) { 'value from block' }
              lkk = key_storage.read(keyspace.last_known_key_key)
              new_key = timestamp_manager.next_key(keyspace, time)
              expect(lkk).to eq(new_key)
            end
          end

          it 'sets a TTL on the build key when a TTL is not explicitly given' do
            subject.fetch(keyspace) { 'value from block' }
            lock_entry = key_storage.store[keyspace.lock_key.to_sym]
            expect(lock_entry[:ttl]).to eq(30)
          end

          it 'sets a TTL on the build key when a TTL is given at fetch time' do
            subject.fetch(keyspace, generate_ttl_ms: 1100) { 'value from block' }
            lock_entry = key_storage.store[keyspace.lock_key.to_sym]
            expect(lock_entry[:ttl]).to eq(1.1)
          end

          it 'sets a TTL on the build key when a value less than a second is given' do
            subject.fetch(keyspace, generate_ttl_ms: 500) { 'value from block' }
            lock_entry = key_storage.store[keyspace.lock_key.to_sym]
            expect(lock_entry[:ttl]).to eq(0.5)
          end

          it 'sets a TTL on the build key when there is a TTL in the default options' do
            subject = AtomicCache::AtomicCacheClient.new(
              storage: cache_storage,
              timestamp_manager: timestamp_manager,
              default_options: { generate_ttl_ms: 600 }
            )

            subject.fetch(keyspace) { 'value from block' }
            lock_entry = key_storage.store[keyspace.lock_key.to_sym]
            expect(lock_entry[:ttl]).to eq(0.6)
          end
        end

        context 'and when another thread is generating the new value,' do
          before(:each) do
            timestamp_manager.lock(keyspace, 100)
          end

          it 'waits for a short duration to see if the other thread generated the value' do
            timestamp_manager.promote(keyspace, last_known_key: 'lkk', timestamp: 1420090000)
            key_storage.set('lkk', 'old:value')
            new_value = 'value from another thread'
            allow(cache_storage).to receive(:read)
              .with(timestamp_manager.current_key(keyspace), anything)
              .and_return(nil, new_value)

            expect(subject.fetch(keyspace, quick_retry_ms: 5) { 'value' }).to eq(new_value)
          end

          context 'when the last known value is present' do
            it 'returns the last known value' do
              timestamp_manager.promote(keyspace, last_known_key: 'lkk', timestamp: 1420090000)
              cache_storage.set('lkk', 'old value')

              result = subject.fetch(keyspace, backoff_duration_ms: 5) { 'value from generate' }
              expect(result).to eq('old value')
            end
          end

          context 'when the last known value is NOT present' do
            it 'waits for another thread to generate the new value' do
              key_storage.set(timestamp_manager.last_modified_time_key, '1420090000')
              new_value = 'value from another thread'

              # multiple returned values here are faking what it would look like to
              # the client if another thread suddenly wrote a value into the cache
              allow(cache_storage).to receive(:read)
                .with(timestamp_manager.current_key(keyspace), anything)
                .and_return(nil, nil, nil, nil, new_value)

              result = subject.fetch(keyspace, backoff_duration_ms: 5) { 'value from generate' }
              expect(result).to eq(new_value)
            end

            it 'stops waiting when the max retry count is reached' do
              timestamp_manager.promote(keyspace, last_known_key: 'asdf', timestamp: 1420090000)
              result = subject.fetch(keyspace, backoff_duration_ms: 5) { 'value from generate' }
              expect(result).to eq(nil)
            end

            it 'deletes the last known key' do
              key_storage.set(keyspace.last_known_key_key, :oldkey)
              cache_storage.set(:oldkey, nil)
              subject.fetch(keyspace, backoff_duration_ms: 5) { 'value from generate' }
              expect(cache_storage.store).to_not have_key(:oldkey)
            end
          end
        end
      end

      context 'and when a block is NOT given' do
        it 'waits for a short duration to see if the other thread generated the value' do
          timestamp_manager.promote(keyspace, last_known_key: 'asdf', timestamp: 1420090000)
          new_value = 'value from another thread'
          allow(cache_storage).to receive(:read)
            .with(timestamp_manager.current_key(keyspace), anything)
            .and_return(nil, new_value)

          result = subject.fetch(keyspace, quick_retry_ms: 50)
          expect(result).to eq(new_value)
        end

        it 'returns nil if nothing is present' do
          expect(subject.fetch(keyspace)).to eq(nil)
        end
      end
    end

  end

end
