## Usage

### Invalidating the Cache on Change
The concern makes the `expire_cache` method available both on the class and on the instance.
```ruby
expire_cache
expire_cache(Time.now - 100) # an optional time can be given
```

### Getting Last Modified Time
The concern makes a `last_modified_time` method available both on the class and on the instance.

### Fetch
The concern makes a `atomic_cache` object available both on the class and on the instance.

```ruby
atomic_cache.fetch(options) do
  # generate block
end
```

In addition to the below options, any other options given (e.g. `expires_in`, `cache_nils`) are passed through to the underlying storage adapter.  This allows storage-specific options to be passed through (reference: [Dalli config](https://github.com/petergoldstein/dalli#configuration)).

#### TTL
Various storage clients require TTL to be expressed in different ways. The included storage adapters will unwrap the `ttl` option to an storage-specific representation.
```ruby
atomic_cache.fetch(ttl: 500) do
  # generate block
end
```

#### `generate_ttl_ms`
_Defaults to 30 seconds._

When a cache client identifies that a cache is empty and that no other processes are actively generating a value, it will establish a lock and attempt to generate the value itself.  However, if that process were to die or the instance on which it's on goes down in addition to being unable to write a cache and the lock that it established would still be active, preventing other processes from generating a new cache value.  To prevent this, the lock *always* has a TTL on it forcing the lock to automatically be removed by the storage mechanism to prevent permanent locks.  `generate_ttl_ms` is the duration of that TTL.

The ideal `generate_ttl_ms` time is just slightly longer than the average generate block duration.  If `generate_ttl_ms` is set too low, the lock might expire before a process has written it's new value and another process will then try and generate an identical value.

If metrics are enabled, the `<namespace>.generate.run` can be used to determine the min/max/average generate time for a particular cache and the `generate_ttl_ms` tuned using that.

#### `max_retries` & `backoff_duration_ms`
_`max_retries` defaults to 5._
_`backoff_duration_ms` defaults to 50ms._

In cases where neither the cached value nor the last known value isn't available the client ends up in a state of polling for the new value, under the assumption that another process is generating that value.  It's possible that the other process went down or is for some reason not able to write the new value to the cache.  If the client didn't stop polling for a value, it would steal all the process time from other requests.  `max_retries` defeats that case by limiting how many times the client can poll before giving up.

The client wait between polling. The duration it waits is `backoff_duration_ms * retry_count * random(1 to 15ms)`. A small random value is added to stagger multiple processes in the case after a deploy where many machines come online close to the same time and all need to same cache.

`backoff_duration_ms` and `max_retries` should both be small values.  Ideally

##### Example retry with durations
`max_retries` = 5
`backoff_duration_ms` = 50ms
Assumes the random offset is always 10ms
Total time spent polling: 800ms

  * First retry - wait 60ms
  * Second retry - wait 110ms
  * Third retry - wait 160ms
  * Fourth retry - wait 210ms
  * Fifth retry - wait 260ms

## Testing

### Integration Style Tests
`AtomicCache::Storage::InstanceMemory` or `AtomicCache::Storage::SharedMemory` can be used to make testing easier by offering an integration testing approach that allows assertion against what ended up in the cache instead of what methods on the cache client were called.  Both storage adapters expose the following methods.

  * `#reset` -- Clears all stored values
  * `#store` -- Returns the underlying hash of values stored

All incoming keys are normalized to symbols.  All values are stored with a `value`, `ttl`, and `written_at` property.

It's likely preferable to use an environments file to configure the `key_storage` and `cache_storage` to always be an in-memory adapter when running in the test environment instead of manually configuring the storage adapter per spec.

#### TTL in Tests
In a test environment, unlike in a production environment, database queries are fast, and time doesn't elapse quite like it does in the real world. As tests get more complex, they perform changes for which they expect the cache to expire. However, because of the synthetic nature of testing, TTLs, particularly those on locks, don't quite work the same either.

There are a few approaches to address this, for example, using `sleep` to cause real time to pass (not preferable) or wrapping each test in a TimeCop, forcing time to pass (works but quite manual).

Since this situation is highly likely to arise, `atomic_cache` provides a feature to globally disable enforcing TTL on locks for the `SharedMemory` implementation. Set `enforce_ttl = false` to disable TTL checking on locks within SharedMemory in a test context. This will prevent tests from failing due to unexpired TTLs on locks. 

#### ★ Testing Tip ★
If using `SharedMemory` for integration style tests, a global `before(:each)` can be configured in `spec_helper.rb`.

```ruby
# spec/spec_helper.rb
RSpec.configure do |config|

  # your other config

  config.before(:each) do
    AtomicCache::Storage::SharedMemory.enforce_ttl = false
    AtomicCache::Storage::SharedMemory.reset
  end
end
```

## Metrics

If a metrics client is configured via the DefaultConfig, the following metrics will be published:

* `<namespace>.read.present` - Number of times a key was fetched and was present in the cache
* `<namespace>.read.not-present` - Number of times a key was fetched and was NOT present in the cache
* `<namespace>.generate.current-thread` - Number of times the value was not present in the cache and the current thread started the task of generating a new value
* `<namespace>.generate.other-thread` - Number of times the value was not present in the cache but another thread was already generating the value
* `<namespace>.empty-cache-retry.present` - Number of times the value was not present, but the client checked again after a short duration and it was present
* `<namespace>.empty-cache-retry.not-present` - Number of times the value was not present, but the client checked again after a short duration and it was NOT present
* `<namespace>.last-known-value.present` - Number of times the value was not present but the last known value was
* `<namespace>.last-known-value.not-present` - Number of times the value was not present and the last known value was not either
* `<namespace>.wait.run` - When the value and last known value isn't available, this timer is the duration it takes to wait for another thread to generate the value before being recognized by the client on the current thread
* `<namespace>.generate.run` - When a new value is being generated, this timer is the duration it takes to generate that new value
