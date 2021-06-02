# frozen_string_literal: true

require 'active_support/core_ext/object'
require 'active_support/core_ext/hash'

module AtomicCache
  class LastModTimeKeyManager
    extend Forwardable

    LOCK_VALUE = 1

    # @param keyspace [AtomicCache::Keyspace] keyspace to store timestamp info at
    # @param storage [Object] cache storage adapter
    # @param timestamp_formatter [Proc] function to turn Time -> String
    def initialize(keyspace: nil, storage: nil, timestamp_formatter: nil)
      @timestamp_keyspace = keyspace
      @storage = storage || DefaultConfig.instance.key_storage
      @timestamp_formatter = timestamp_formatter || DefaultConfig.instance.timestamp_formatter

      raise ArgumentError.new("`storage` required but none given") unless @storage.present?
      raise ArgumentError.new("`root_keyspace` required but none given") unless @storage.present?
    end

    # get the key at the given keyspace, suffixed by the current timestamp
    #
    # @param keyspace [AtomicCache::Keyspace] keyspace to namespace this key with
    # @return [String] a timestamped key
    def current_key(keyspace)
      keyspace.key(last_modified_time)
    end

    # get a key at the given keyspace, suffixed by given timestamp
    #
    # @param keyspace [AtomicCache::Keyspace] keyspace to namespace this key with
    # @param timestamp [String, Numeric, Time] timestamp
    # @return [String] a timestamped key
    def next_key(keyspace, timestamp)
      keyspace.key(self.format(timestamp))
    end

    # promote a key and timestamp after a successful re-generation of a cache keyspace
    #
    # @param keyspace [AtomicCache::Keyspace] keyspace to promote within
    # @param last_known_key [String] a key with a known value to refer other processes to
    # @param timestamp [String, Numeric, Time] the timestamp with which the last_known_key was updated at
    def promote(keyspace, last_known_key:, timestamp:)
      key = keyspace.last_known_key_key
      @storage.set(key, last_known_key)
      @storage.set(last_modified_time_key, self.format(timestamp))
    end

    # prevent other processes from modifying the given keyspace
    #
    # @param keyspace [AtomicCache::Keyspace] keyspace to lock
    # @param ttl [Numeric] the duration in ms to lock (auto expires after duration is up)
    # @param options [Hash] options to pass to the storage adapter
    def lock(keyspace, ttl, options={})
      # returns false if the key already exists
      @storage.add(keyspace.lock_key, LOCK_VALUE, ttl, options)
    end

    # remove existing lock to allow other processes to update keyspace
    #
    # @param keyspace [AtomicCache::Keyspace] keyspace to lock
    def unlock(keyspace)
      @storage.delete(keyspace.lock_key)
    end

    def last_known_key(keyspace)
      @storage.read(keyspace.last_known_key_key)
    end

    def last_modified_time_key
      @lmtk ||= @timestamp_keyspace.key('lmt')
    end

    def last_modified_time
      @storage.read(last_modified_time_key)
    end

    def last_modified_time=(timestamp=Time.now)
      @storage.set(last_modified_time_key, self.format(timestamp))
    end

    protected

    def format(time)
      if time.is_a?(Time)
        @timestamp_formatter.call(time)
      else
        time
      end
    end

  end
end
