# frozen_string_literal: true

require 'spec_helper'

class FakeDalli
  def add(key, new_value, ttl, user_options); end
  def read(key, user_options); end
  def set(key, new_value, user_options); end
  def delete(key, user_options); end
  def close(); end
  def reset(); end
end

describe 'Dalli' do
  let(:dalli_client) { FakeDalli.new }
  subject { AtomicCache::Storage::Dalli.new(dalli_client) }

  context '#set' do
    it 'delegates #set without options' do
      expect(dalli_client).to receive(:set).with('key', 'value', nil, {})
      subject.set('key', 'value')
    end

    it 'delegates #set with TTL' do
      expect(dalli_client).to receive(:set).with('key', 'value', 500, {})
      subject.set('key', 'value', { ttl: 500 })
    end
  end

  it 'delegates #read without options' do
    expect(dalli_client).to receive(:get).with('key', {}).and_return('asdf')
    subject.read('key')
  end

  it 'delegates #delete' do
    expect(dalli_client).to receive(:delete).with('key')
    subject.delete('key')
  end

  it 'delegates #close' do
    expect(dalli_client).to receive(:close)
    subject.close
  end

  it 'delegates #reset' do
    expect(dalli_client).to receive(:reset)
    subject.reset
  end

  context '#add' do
    before(:each) do
      allow(dalli_client).to receive(:add).and_return(false)
    end

    it 'delegates to #add with the raw option set' do
      expect(dalli_client).to receive(:add)
        .with('key', 'value', 100, { foo: 'bar', raw: true })
      subject.add('key', 'value', 100, { foo: 'bar' })
    end

    it 'returns true when the add is successful' do
      expect(dalli_client).to receive(:add).and_return(12339031748204560384)
      result = subject.add('key', 'value', 100)
      expect(result).to eq(true)
    end

    it 'returns false if the key already exists' do
      expect(dalli_client).to receive(:add).and_return(false)
      result = subject.add('key', 'value', 100)
      expect(result).to eq(false)
    end

  end

end
