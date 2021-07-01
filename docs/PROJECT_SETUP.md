## Gem Installation
Add this line to your application's Gemfile:

```ruby
gem 'atomic_cache'
```

And then execute:

    $ bundle

## Project Setup
`AtomicCache::DefaultConfig` is a singleton which allows global configuration.

#### Rails Initializer Example
```ruby
# config/initializers/cache.rb
require 'datadog/statsd'
require 'atomic_cache'

AtomicCache::DefaultConfig.configure do |config|
  config.logger  = Rails.logger
  config.metrics = Datadog::Statsd.new('localhost', 8125, namespace: 'cache.atomic')

  # note: these values can also be set in an env file for env-specific settings
  config.namespace        = 'atom'
  config.default_options  = { generate_ttl_ms: 500 }
  config.cache_storage    = AtomicCache::Storage::SharedMemory.new
  config.key_storage      = AtomicCache::Storage::SharedMemory.new
end
```

Note that `Datadog::Statsd` is not _required_.  Adding it, however, will enable metrics support.

#### Required
  * `cache_storage` - Storage adapter for cache (see below)
  * `key_storage` - Storage adapter for key manager (see below)

#### Optional
  * `default_options` - Override default options for every fetch call, unless specified at call site.  See [fetch options](/Ibotta/atomic_cache/blob/main/docs/USAGE.md#fetch).
  * `logger` - Logger instance.  Used for debug and warn logs. Defaults to nil.
  * `timestamp_formatter` - Proc to format last modified time for storage. Defaults to timestamp (`Time.to_i`)
  * `metrics` - Metrics instance. Defaults to nil.
  * `namespace` - Global namespace that will prefix all cache keys. Defaults to nil.

#### ★ Best Practice ★
Keep the global namespace short.  For example, memcached has a limit of 250 characters for key length.

#### More Complex Rails Configuration

In any real-world project, the need to run multiple caching strategies or setups is likely to arise. In those cases, it's often advantageous
to keep a DRY setup, with multiple caching clients sharing the same config. Because Rails initializers run after the environment-specific
config files, a sane way to manage this is to keep client network settings int he config files, then reference them from the initializer.

```ruby
# config/environments/staging
config.memcache_hosts = [ "staging.host.cache.amazonaws.com" ]
config.cache_store_options = {
  expires_in: 15.minutes,
  compress: true,
  # ...
}

# config/environments/production
config.memcache_hosts = [ "prod1.host.cache.amazonaws.com", "prod2.host.cache.amazonaws.com" ]
config.cache_store_options = {
  expires_in: 1.hour,
  compress: true,
  # ...
}

# config/initializers/cache.rb
AtomicCache::DefaultConfig.configure do |config|
  if Rails.env.development? || Rails.env.test?
    config.cache_storage  = AtomicCache::Storage::SharedMemory.new
    config.key_storage    = AtomicCache::Storage::SharedMemory.new

  elsif Rails.env.staging? || Rails.env.production?
    # Your::Application.config will be loaded by config/environments/*
    memcache_hosts = Your::Application.config.memcache_hosts
    options = Your::Application.config.cache_store_options
    
    dc = Dalli::Client.new(memcache_hosts, options)
    config.cache_storage  = AtomicCache::Storage::Dalli.new(dc)
    config.key_storage    = AtomicCache::Storage::Dalli.new(dc)
  end
  
  # other AtomicCache configuration...
end
```

## Storage Adapters

### InstanceMemory & SharedMemory
Both of these storage adapters provide a cache storage implementation that is limited to a single ruby instance.  The difference is that `InstanceMemory` maintains a private store that is only visible when interacting with that instance of the adapter where as `SharedMemory` creates a class-scoped store such that all instances of the storage adapter read and write from the same store.  `InstanceMemory` is great for integration testing as it isolates visibility of the store and `SharedMemory` is great for local development and integration testing in cases where multiple components reading and writing needs to be represented.

Neither memory storage implementation should be considered "production ready".  Both respect TTL but only evaluate it on read meaning that data is only removed from the store when it's attempted to be read and the TTL is evaluated as expired.

##### Example
```ruby
AtomicCache::DefaultConfig.configure do |config|
  config.key_storage = AtomicCache::Storage::InstanceMemory.new
end
```

### Dalli
The `Dalli` storage adapter provides a thin wrapper around the Dalli client.

##### Example
```ruby
dc = Dalli::Client.new('localhost:11211', options)
AtomicCache::DefaultConfig.configure do |config|
  config.key_storage = AtomicCache::Storage::Dalli.new(dc)
end
```
