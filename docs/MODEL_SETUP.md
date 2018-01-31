## Model Setup
Include the `GlobalLMTCacheConcern`.

```ruby
class Foo < ActiveRecord::Base
  include AtomicCache::GlobalLMTCacheConcern
end
```

### cache_class
By default the cache identifier for a class is set to the name of a class (ie. `self.to_s`).  In some cases it makes sense to set a custom value for the cache identifier.  In cases where a custom cache identifier is set, it's important that the identifier remain unique across the project.

```ruby
class SuperDescriptiveDomainModelAbstractFactoryImplManager < ActiveRecord::Base
  include AtomicCache::GlobalLMTCacheConcern
  cache_class('sddmafim')
end
```

#### ★ Best Practice ★
Generally it should only be necessary to explicitly set a `cache_class` in cases where the class name is extremely long and causing the max key length to be hit.  In such a case the `cache_class` can be set to an abbreviation of the class name.

### cache_version
In cases where a code change that is incompatible with cached values already written needs to be deployed, a cache version can be set which further sub-divides the cache namespace, preventing old values from being read.  When the version is `nil` (the default), no version is added to the cache key.

```ruby
class Foo < ActiveRecord::Base
  include AtomicCache::GlobalLMTCacheConcern
  cache_version(5)
end
```
