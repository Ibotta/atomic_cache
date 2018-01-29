# frozen_string_literal: true

require 'spec_helper'

shared_examples 'memory storage' do
  before(:each) do
    subject.reset
  end

  context '#add' do
    it 'writes the new key if it does not already exist' do
      result = subject.add('key', 'value', 100)

      expect(subject.store).to have_key(:key)
      expect(subject.store[:key][:value]).to eq('value')
      expect(subject.store[:key][:ttl]).to eq(100)
      expect(result).to eq(true)
    end

    it 'does not write the key if it exists' do
      entry = { value: 'foo', ttl: 100, written_at: 100 }
      subject.store[:key] = entry

      result = subject.add('key', 'value', 200)
      expect(result).to eq(false)

      # stored values should not have changed
      expect(subject.store).to have_key(:key)
      expect(subject.store[:key][:value]).to eq('foo')
      expect(subject.store[:key][:ttl]).to eq(100)
    end
  end

  context '#read' do
    it 'returns values' do
      subject.store[:sugar] = { value: 'foo' }
      expect(subject.read('sugar')).to eq('foo')
    end

    it 'respects TTL' do
      subject.store[:sugar] = { value: 'foo', ttl: 100, written_at: Time.now - 1000 }
      expect(subject.read('sugar')).to eq(nil)
    end
  end

  context '#set' do
    it 'adds the value when not present' do
      subject.set(:cane, 'v', expires_in: 100)
      expect(subject.store).to have_key(:cane)
      expect(subject.store[:cane][:value]).to eq('v')
      expect(subject.store[:cane][:ttl]).to eq(100)
    end

    it 'overwrites existing values' do
      subject.store[:cane] = { value: 'foo', ttl: 500, written_at: 500 }

      subject.set(:cane, 'v', expires_in: 100)
      expect(subject.store).to have_key(:cane)
      expect(subject.store[:cane][:value]).to eq('v')
      expect(subject.store[:cane][:ttl]).to eq(100)
    end
  end

  context '#delete' do
    it 'deletes the key' do
      subject.store[:record] = { value: 'foo', written_at: 500 }
      subject.delete('record')
      expect(subject.store).to_not have_key(:record)
    end
  end

end
