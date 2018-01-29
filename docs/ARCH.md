
## Overview
The problem of handling the scope of timestamps for multiple caches within a single context is more nuanced than it appears at first.  The most common context is a model class. That will be used as the example through this documentation, but this gem could support other contexts as well.

Any single model class may have multiple caches associated with it, for example, a cache of all active or inactive instances of the model.  When any instance of that class changes, which changes become invalidated?  A simple solution is to keep one last modified time that is within scope for all instances of the class, and a change to any instance results in a change of the last modified time.  Likewise, a change to the last modified time of the model would need to result in an invalidation of all collection caches.  Thus, the last modified time is at a broader scope than any individual cache.  In addition, what is often viewed as a single key or an individual cache is actually a collection of similar keys oriented around storing one logical value.  The reason for this is the cache client has a fall-through stack where it tries to find the best value; it possibly needs to look into several cache keys before finding the best value, thus it needs to understand the namespace (or collection of sub-keys), not just a single string.

The implementation of this gem handles this by separating management of the last modified time value into a "timestamp manager" and encapsulation of all the sub-keys for a given cache into a "keyspace".  Because the timestamp manager maintains a timestamp which has a scope larger than any single logical value being stored it stores this time in a parent keyspace.  Additional caches for that model are then child keyspaces which namespace themselves relative to the parent and their specific concern.

To keep things simple, when using a concern, there is a one-to-one correlation between a cache client instance and a timestamp manager.  In the common case this simplifies needing to know about these individual parts and lets users just get to the tasks of fetching and writing caches.  At runtime the cache client only requires the namespace in order to operate, and automatically uses the last modified time from it's timestamp manager.

#### Terms
  * *Keyspace* - Responsible for knowing the namespace and generating all the sub keys for a logical cache location
  * *TimestampManager* - Responsible for managing and storing the last modified time.  Represents a logical scope of cache invalidation.
  * *CacheClient* - The distributed lock implementation. Responsible for fetching the best value for a keyspace.
  * *StorageAdapter* - Interface to storage facility

#### Storage Locations
The gem stores data in two locations, a key store and a cache store.

##### Stored in the Atomic Cache Client's storage:
  * cached value

###### Stored in the Key Keyspace's storage:
  * atomic lock
  * last known key
  * last modified time

### Keyspace Keys
Example keys assume use of concern.  `id` in this context is whatever is given when `cache_keyspace` is run.

  * *last modified time* - `<namespace>:<class name>:<version>:lmt`
  * *value* - `<namespace>:<class name>:<version>:<id>:<timestamp>`
  * *last known key* -  `<namespace>:<class name>:<version>:<id>:lkk`
  * *lock* -  `<namespace>:<class name>:<version>:<id>:lock`
