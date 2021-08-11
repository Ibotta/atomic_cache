## Model Setup
Include the `GlobalLMTCacheConcern`.

```ruby
class Foo < ActiveRecord::Base
  include AtomicCache::GlobalLMTCacheConcern
end
```

### force_cache_class
By default the cache identifier for a class is set to the name of a class (ie. `self.to_s`).  In some cases it makes sense to set a custom value for the cache identifier.  In cases where a custom cache identifier is set, it's important that the identifier remain unique across the project.

```ruby
class SuperDescriptiveDomainModelAbstractFactoryImplManager < ActiveRecord::Base
  include AtomicCache::GlobalLMTCacheConcern
  force_cache_class('sddmafim')
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

### Inheritance

When either `force_cache_class` or `cache_version` are used, those values will always be preferred by classes which inherit from the class on which those macros exist. When macros are used on descendant classes, the "closet" value wins.

#### Example #1
The keys used by `Bar` will be prefixed with `custom:v5`, as it prefers both the 'custom' class name and version 5 from the parent.
```ruby
class Foo < ActiveRecord::Base
  include AtomicCache::GlobalLMTCacheConcern
  force_cache_class('custom')
  cache_version(5)
end

class Bar < Foo
end
```

#### Example #2
The keys used by `Bar` will be prefixed with `bar:v5`, as the version 5 is taken from the parent, but the use of forcing on the child class result in the cache class of 'bar'.
```ruby
class Foo < ActiveRecord::Base
  include AtomicCache::GlobalLMTCacheConcern
  cache_version(5)
end

class Bar < Foo
  force_cache_class('bar')
end
```

#### Example #3
The keys used by `Bar` will be still be prefixed with `bar:v5` for the same reasons as above.
```ruby
class Foo < ActiveRecord::Base
  include AtomicCache::GlobalLMTCacheConcern
  force_cache_class('custom')
  cache_version(5)
end

class Bar < Foo
  force_cache_class('bar')
end
```

### Rails Model Inheritance

It's not uncommon in rails to end up with model inhertiance. For example:

```ruby
class Content < ActiveRecord::Base
  include AtomicCache::GlobalLMTCacheConcern
  force_cache_class('content')
end

class BlogPost < Content
end
```

If these models will be cached together into a single key, it's preferable to force the cache class on the parent, causing all the descendant types to use the same keyspace. Not doing this will cause each subtype to use it's own last modified time.

If the models will be treated as separate collections and cached separately, this is not recommended. Alternately, if only some subtypes will be cached together, those should share a forced cache class and version.
