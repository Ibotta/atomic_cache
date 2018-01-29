# frozen_string_literal: true

require 'spec_helper'

describe 'Keyspace' do
  subject { AtomicCache::Keyspace.new(namespace: ['foo', 'bar'], root: 'foo') }

  context '#initialize' do
    it 'hashes non-primitive types' do
      ids = [1,2,3]
      ns1 = AtomicCache::Keyspace.new(namespace: ['foo', ids])
      hash = ns1.send(:hexhash, ids)
      expect(ns1.namespace).to eq(['foo', hash])
    end

    it 'leaves primitives alone' do
      ns1 = AtomicCache::Keyspace.new(namespace: ['foo', :foo, 5])
      expect(ns1.namespace).to eq(['foo', :foo, 5])
    end

    it 'sorts sortable values before hashing' do
      ns1 = AtomicCache::Keyspace.new(namespace: ['foo', [1, 2, 3]])
      ns2 = AtomicCache::Keyspace.new(namespace: ['foo', [3, 2, 1]])
      expect(ns1.namespace).to eq(ns2.namespace)
    end
  end

  context '#child' do
    it 'extends the keyspace' do
      ns2 = subject.child([:buz, :baz])
      expect(ns2.namespace).to eq(['foo', 'bar', :buz, :baz])
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
