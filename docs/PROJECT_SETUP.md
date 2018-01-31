## Gem Installation

You will need to ensure you have the correct deploy credentials

Add these lines to your application's Gemfile:

```ruby
source 'https://ibdolphin.jfrog.io/ibdolphin/api/gems/gems-private/' do
  gem 'atomic_cache'
end
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install atomic_cache


## Project Setup
`AtomicCache::DefaultConfig` is a singleton which allows global configuration.

#### Rails Initializer Example
```ruby
# config/initializers/cache.rb
require 'datadog/statsd'
require 'atomic_cache'

AtomicCache::DefaultConfig.configure do |config|
  config.logger    = Rails.logger
  config.metrics   = Datadog::Statsd.new('localhost', 8125, namespace: 'cache.atomic')
  config.namespace = 'atom'
end
```

#### Required
  * `cache_storage` - Storage adapter for cache (see below)
  * `key_storage` - Storage adapter for key manager (see below)

#### Optional
  * `default_options` - Default options for every fetch call.  See [options](TODO: LINK).
  * `logger` - Logger instance.  Used for debug and warn logs. Defaults to nil.
  * `timestamp_formatter` - Proc to format last modified time for storage. Defaults to timestamp (`Time.to_i`)
  * `metrics` - Metrics instance. Defaults to nil.
  * `namespace` - Global namespace that will prefix all cache keys. Defaults to nil.

#### ★ Best Practice ★
Keep the global namespace short.  For example, memcached has a limit of 250 characters for key length.

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
