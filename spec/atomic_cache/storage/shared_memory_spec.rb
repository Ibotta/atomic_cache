# frozen_string_literal: true

require 'spec_helper'
require_relative 'memory_spec'

describe 'SharedMemory' do
  subject { AtomicCache::Storage::SharedMemory.new }
  it_behaves_like 'memory storage'

  context 'enforce_ttl disabled' do
    before(:each) do
      AtomicCache::Storage::SharedMemory.enforce_ttl = false
    end

    it 'allows instantly `add`ing keys' do
      subject.add("foo", 1, ttl: 100000)
      subject.add("foo", 2, ttl: 1)

      expect(subject.store).to have_key(:foo)
      expect(Marshal.load(subject.store[:foo][:value])).to eq(2)
    end
  end
end
