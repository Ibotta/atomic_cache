## Storage Adapter
Any options passed in by the user at fetch time will be passed through to the storage adapter.

```ruby
class StorageAdapter
  # (String, Object, Integer, Hash) -> Boolean
  # ttl is in millis
  # operation must be atomic
  # returns true when the key doesn't exist and was written successfully
  # returns false in all other cases
  def add(key, new_value, ttl, user_options); end

  # (String, Hash) -> String
  # return the `value` at `key`
  def read(key, user_options); end

  # (String, Object) -> Boolean
  # returns true if it succeeds; false otherwise
  def set(key, new_value, user_options); end

  # (String) -> Boolean
  # returns true if it succeeds; false otherwise
  def delete(key, user_options); end
end
```

## Metrics
```ruby
class Metrics
  # (String, Hash) -> Nil
  def increment(key, options); end
  # (String, Hash, Block) -> Nil
  def time(key, options, &block); end
end
```

## Logger
```ruby
class Logger
  # (Object) -> Nil
  def warn(msg); end
  def info(msg); end
  def debug(msg); end
end
```
