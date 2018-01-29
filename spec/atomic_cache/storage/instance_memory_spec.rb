# frozen_string_literal: true

require 'spec_helper'
require_relative 'memory_spec'

describe 'InstanceMemory' do
  subject { AtomicCache::Storage::InstanceMemory.new }
  it_behaves_like 'memory storage'
end
