# frozen_string_literal: true

require 'spec_helper'
require_relative 'memory_spec'

describe 'SharedMemory' do
  subject { AtomicCache::Storage::SharedMemory.new }
  it_behaves_like 'memory storage'
end
