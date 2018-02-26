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
      expect(Marshal.load(subject.store[:key][:value])).to eq('value')
      expect(subject.store[:key][:ttl]).to eq(100)
      expect(result).to eq(true)
    end

    it 'does not write the key if it exists' do
      entry = { value: Marshal.dump('foo'), ttl: 100, written_at: 100 }
      subject.store[:key] = entry

      result = subject.add('key', 'value', 200)
      expect(result).to eq(false)

      # stored values should not have changed
      expect(subject.store).to have_key(:key)
      expect(Marshal.load(subject.store[:key][:value])).to eq('foo')
      expect(subject.store[:key][:ttl]).to eq(100)
    end
  end

  context '#read' do
    it 'returns values' do
      subject.store[:sugar] = { value: Marshal.dump('foo') }
      expect(subject.read('sugar')).to eq('foo')
    end

    it 'respects TTL' do
      subject.store[:sugar] = { value: Marshal.dump('foo'), ttl: 100, written_at: Time.now - 1000 }
      expect(subject.read('sugar')).to eq(nil)
    end

    it 'returns complex objects' do
      class ComplexObject
        attr_accessor :foo, :bar
      end

      obj = ComplexObject.new
      obj.foo = 'f'
      obj.bar = [1,2,3]

      subject.set(:complex, obj)

      obj2 = subject.read(:complex)
      expect(obj2.foo).to eql('f')
      expect(obj2.bar).to eql([1,2,3])
    end
  end

  context '#set' do
    it 'adds the value when not present' do
      subject.set(:cane, 'v', expires_in: 100)
      expect(subject.store).to have_key(:cane)
      expect(Marshal.load(subject.store[:cane][:value])).to eq('v')
      expect(subject.store[:cane][:ttl]).to eq(100)
    end

    it 'overwrites existing values' do
      subject.store[:cane] = { value: 'foo', ttl: 500, written_at: 500 }

      subject.set(:cane, 'v', expires_in: 100)
      expect(subject.store).to have_key(:cane)
      expect(Marshal.load(subject.store[:cane][:value])).to eq('v')
      expect(subject.store[:cane][:ttl]).to eq(100)
    end
  end

  context '#delete' do
    it 'deletes the key' do
      subject.store[:record] = { value: Marshal.dump('foo'), written_at: 500 }
      subject.delete('record')
      expect(subject.store).to_not have_key(:record)
    end
  end

end
