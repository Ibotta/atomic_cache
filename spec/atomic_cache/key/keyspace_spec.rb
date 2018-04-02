# frozen_string_literal: true

require 'spec_helper'

describe 'Keyspace' do
  subject { AtomicCache::Keyspace.new(namespace: ['foo', 'bar'], root: 'foo') }

  context '#initialize' do

    it 'sorts sortable values before hashing' do
      ks1 = AtomicCache::Keyspace.new(namespace: ['foo', [1, 2, 3]])
      ks2 = AtomicCache::Keyspace.new(namespace: ['foo', [3, 2, 1]])
      expect(ks1.namespace).to eq(ks2.namespace)
    end

    context 'namespace' do
      it 'accepts nil' do
        ks = AtomicCache::Keyspace.new(namespace: nil)
        expect(ks.namespace).to eq([])
      end

      it 'accepts single values' do
        ks = AtomicCache::Keyspace.new(namespace: 'foo')
        expect(ks.namespace).to eq(['foo'])
      end

      it 'hashes non-primitive types' do
        ids = [1,2,3]
        ks1 = AtomicCache::Keyspace.new(namespace: ['foo', ids])
        hash = ks1.send(:hexhash, ids)
        expect(ks1.namespace).to eq(['foo', hash])
      end

      it 'leaves primitives alone' do
        ks1 = AtomicCache::Keyspace.new(namespace: ['foo', :foo, 5])
        expect(ks1.namespace).to eq(['foo', :foo, 5])
      end

      it 'expands timestamps' do
        formatter = Proc.new { |t| 'formatted' }
        ks = AtomicCache::Keyspace.new(namespace: Time.new, timestamp_formatter: formatter)
        expect(ks.namespace).to eq(['formatted'])
      end
    end
  end

  context '#child' do
    it 'extends the keyspace' do
      ks2 = subject.child([:buz, :baz])
      expect(ks2.namespace).to eq(['foo', 'bar', :buz, :baz])
    end
  end

  context '#key' do
    it 'return a key of the segments' do
      expect(subject.key).to eq('foo:bar')
    end

    it 'return the key with the suffix' do
      expect(subject.key('baz')).to eq('foo:bar:baz')
    end
  end

end
