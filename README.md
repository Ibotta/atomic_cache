# atomic_cache Gem
[![Gem Version](https://badge.fury.io/rb/atomic_cache.svg)](https://badge.fury.io/rb/atomic_cache)
[![Build Status](https://travis-ci.org/Ibotta/atomic_cache.svg?branch=master)](https://travis-ci.org/Ibotta/atomic_cache)
[![Test Coverage](https://api.codeclimate.com/v1/badges/790faad5866d2a00ca6c/test_coverage)](https://codeclimate.com/github/Ibotta/atomic_cache/test_coverage)

## User Documentation
 * [Installation & Project Setup](docs/PROJECT_SETUP.md)
 * [Model Setup](docs/MODEL_SETUP.md)
 * [Usage & Testing](docs/USAGE.md)
 * [Custom Clients/Adapters](docs/INTERFACES.md)

#### atomic_cache is a gem which prevents the [thundering herd problem](https://en.wikipedia.org/wiki/Thundering_herd_problem)
In a nutshell:
 * The key of every cached value includes a timestamp
 * Once a cache key is written to, it is never written over
 * When a newer version of a cached value is available, it's written to a new key (e.g. same key with a newer timestamp)
 * When a new value is being generated for a new key only 1 process is allowed to do so at a time
 * While the new value is being generated, other processes read one key older than most recent (last known value)
 * If the last known value isn't available other processes wait for the new value, polling periodically for it

#### Quick Reference
```ruby
class Foo < ActiveRecord::Base
  include AtomicCache::GlobalLMTCacheConcern

  cache_class(:custom_foo)  # optional
  cache_version(5)          # optional

  def active_foos(ids)
    keyspace = cache_keyspace(:activeids, ids)
    AtomicCache.fetch(keyspace, expires_in: 5.minutes) do
      Foo.active.where(id: ids.uniq)
    end

    # value stored at 'company:custom_foo:activeids:<ids hash>:1270643035.04671'
    # last mod time stored at 'company:custom_foo:lmt'
  end
end
```
For further details and examples see [Usage & Testing](docs/USAGE.md)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ibotta/atomic_cache

## Releasing

Releases are automatically handled via the Travis CI build. When a version greater than
the version published on rubygems.org is pushed to the `master` branch, Travis will:

- re-generate the CHANGELOG file
- tag the release with GitHub
- release to rubygems.org
