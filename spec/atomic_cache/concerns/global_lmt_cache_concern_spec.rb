# frozen_string_literal: true

require 'spec_helper'

describe 'AtomicCacheConcern' do
  let(:key_storage) { DefaultConfig.instance.key_storage }
  let(:cache_storage) { DefaultConfig.instance.cache_storage }

  subject do
    class Foo1
      include AtomicCache::GlobalLMTCacheConcern
    end
  end

  before(:context) do
    DefaultConfig.instance.reset
    DefaultConfig.configure do |cfg|
      cfg.cache_storage = AtomicCache::Storage::SharedMemory.new
      cfg.key_storage = AtomicCache::Storage::SharedMemory.new
      cfg.timestamp_formatter = Proc.new { |time| time.to_i }
    end
  end

  before(:each) do
    key_storage.reset
    cache_storage.reset
  end

  context 'AtomicCache' do
    it 'initializes a cache client' do
      expect(subject).to respond_to(:AtomicCache)
      expect(subject.AtomicCache).to be_a(AtomicCacheClient)
      expect(subject.new.AtomicCache).to be_a(AtomicCacheClient)
    end

    it 'uses the name of the class in the default keyspace' do
      subject.expire_cache
      expect(key_storage.store).to have_key(:'foo1:lmt')
    end
  end

  context '#expire_cache' do
    it 'updates the last modified time' do
      time = Time.local(2018, 1, 1, 15, 30, 0)
      subject.expire_cache(time)
      expect(key_storage.store).to have_key(:'foo1:lmt')
      expect(key_storage.store[:'foo1:lmt'][:value]).to eq(time.to_i.to_s)
    end

    it 'expires all the keyspaces for this class' do
      old_time = Time.local(2018, 1, 1, 15, 30, 0)
      new_time = Time.local(2018, 1, 1, 15, 40, 0)
      ns1 = subject.cache_keyspace(:bar)
      ns2 = subject.cache_keyspace(:buz)

      Timecop.freeze(old_time) do
        subject.AtomicCache.fetch(ns1) { 'bar' }
        subject.AtomicCache.fetch(ns2) { 'buz' }
      end

      Timecop.freeze(new_time) do
        subject.expire_cache
        lmt = subject.last_modified_time

        # some other process writes new values
        cache_storage.set("foo1:bar:#{lmt}", 'new-bar')
        cache_storage.set("foo1:buz:#{lmt}", 'new-buz')

        ns1_value = subject.AtomicCache.fetch(ns1)
        ns2_value = subject.AtomicCache.fetch(ns2)

        expect(ns1_value).to eq('new-bar')
        expect(ns2_value).to eq('new-buz')
      end
    end
  end

  context '#cache_keyspace' do
    it 'returns a child keyspace of the class keyspace' do
      ns = subject.cache_keyspace(:fuz, :baz)
      expect(ns).to be_a(Keyspace)
      expect(ns.namespace).to eq(['foo1', :fuz, :baz])
    end
  end

  context 'keyspace macros' do
    subject do
      class Foo2
        include AtomicCache::GlobalLMTCacheConcern
        cache_version(3)
        cache_class('foo')
      end
      Foo2
    end

    it 'uses the given version and cache_class become part of the cache keyspace' do
      subject.expire_cache
      expect(key_storage.store).to have_key(:'foo:v3:lmt')
    end
  end

  context 'storage macros' do
    subject do
      class Foo3
        include AtomicCache::GlobalLMTCacheConcern
        cache_key_storage('keystore')
        cache_value_storage('valuestore')
      end
      Foo3
    end

    it 'sets the storage for the class' do
      cache_store = subject.AtomicCache.instance_variable_get(:@storage)
      expect(cache_store).to eq('valuestore')

      key_store = subject.instance_variable_get(:@timestamp_manager).instance_variable_get(:@storage)
      expect(key_store).to eq('keystore')
    end
  end

end
