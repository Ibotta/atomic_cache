# frozen_string_literal: true

require 'spec_helper'

describe 'LastModTimeKeyManager' do
  let(:id) { :foo }
  let(:timestamp) { 1513720308 }
  let(:storage) { AtomicCache::Storage::InstanceMemory.new }
  let(:timestamp_keyspace) { Keyspace.new(namespace: ['ts'], root: 'foo') }
  let(:req_keyspace) { Keyspace.new(namespace: ['ns'], root: 'bar') }

  subject do
    AtomicCache::LastModTimeKeyManager.new(
      keyspace: timestamp_keyspace,
      storage: storage,
      timestamp_formatter: Proc.new { |t| t.to_i }
    )
  end

  it 'returns the #next_key' do
    expect(subject.next_key(req_keyspace, timestamp)).to eq('ns:1513720308')
  end

  it 'gets and sets the #last_known_key' do
    subject.promote(req_keyspace, last_known_key: 'bar:foo:1513600308', timestamp: timestamp)
    expect(subject.last_known_key(req_keyspace)).to eq('bar:foo:1513600308')
    expect(storage.store).to have_key(:'ns:lkk')
  end

  it 'returns the #last_mod_time_key' do
    expect(subject.last_modified_time_key).to eq('ts:lmt')
  end

  it 'locks and unlocks' do
    locked = subject.lock(req_keyspace, 100)
    expect(storage.store).to have_key(:'ns:lock')
    expect(locked).to eq(true)

    subject.unlock(req_keyspace)
    expect(storage.store).to_not have_key(:'ns:lock')
  end

  it 'promotes a timestamp and last known key' do
    subject.promote(req_keyspace, last_known_key: 'asdf', timestamp: timestamp)
    expect(storage.read(:'ns:lkk')).to eq('asdf')
    expect(storage.read(:'ts:lmt')).to eq(timestamp)
    expect(subject.last_modified_time).to eq(timestamp)
  end

  context '#last_modified_time=' do
    it 'returns the last modified time' do
      subject.last_modified_time = timestamp
      expect(storage.read(:'ts:lmt')).to eq(timestamp)
      expect(subject.last_modified_time).to eq(timestamp)
    end

    it 'formats Time' do
      now = Time.now
      subject.last_modified_time = now
      expect(subject.last_modified_time).to eq(now.to_i)
    end
  end

end
