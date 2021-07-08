require 'simplecov'
SimpleCov.start

require 'bundler/setup'
require 'atomic_cache'
require 'timecop'

DefaultConfig = AtomicCache::DefaultConfig
AtomicCacheClient = AtomicCache::AtomicCacheClient
Keyspace = AtomicCache::Keyspace

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.syntax = :expect
  end

  config.before(:each) do
    AtomicCache::Storage::SharedMemory.enforce_ttl = true
  end
end
