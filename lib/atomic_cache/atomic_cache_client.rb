# frozen_string_literal: true

require 'active_support/core_ext/object'
require 'active_support/core_ext/hash'

module AtomicCache
  class AtomicCacheClient

    DEFAULT_MAX_RETRIES = 5
    DEFAULT_GENERATE_TIME_MS = 30000 # 30 seconds
    BACKOFF_DURATION_MS = 50

    # @param storage [Object] Cache storage adapter
    # @param timestamp_manager [Object] Timestamp manager
    # @param default_options [Hash] Default fetch options
    # @param logger [Object] Logger
    # @param metrics [Object] Metrics client
    def initialize(storage: nil, timestamp_manager: nil, default_options: {}, logger: nil, metrics: nil)
      @default_options = (DefaultConfig.instance.default_options&.clone || {}).merge(default_options || {})
      @timestamp_manager = timestamp_manager
      @logger = logger || DefaultConfig.instance.logger
      @metrics = metrics || DefaultConfig.instance.metrics
      @storage = storage || DefaultConfig.instance.cache_storage

      raise ArgumentError.new("`timestamp_manager` required but none given") unless @timestamp_manager.present?
      raise ArgumentError.new("`storage` required but none given") unless @storage.present?
    end

    # Attempts to fetch the given keyspace, using an optional block to generate
    # a new value when the cache is expired
    #
    # @param keyspace [AtomicCache::Keyspace] the keyspace to fetch
    # @option options [Numeric] :generate_ttl_ms (30000) Max generate duration in ms
    # @option options [Numeric] :max_retries (5) Max times to rety in waiting case
    # @option options [Numeric] :backoff_duration_ms (50) Duration in ms to wait between retries
    # @yield Generates a new value when cache is expired
    def fetch(keyspace, options={}, &blk)
      key = @timestamp_manager.current_key(keyspace)
      tags = ["cache_keyspace:#{keyspace.root}"]

      # happy path: see if the value is there in the key we expect
      value = @storage.read(key, options) if key.present?
      if !value.nil?
        metrics(:increment, 'read.present', tags: tags)
        log(:debug, "Read value from key: '#{key}'")
        return value
      end

      metrics(:increment, 'read.not-present', tags: tags)
      log(:debug, "Cache key `#{key}` not present.")

      # try to generate a new value if another process already isn't
      if block_given?
        new_value = generate_and_store(keyspace, options, tags, &blk)
        return new_value unless new_value.nil?
      end

      # attempt to fall back to the last known value
      value = last_known_value(keyspace, options, tags)
      return value if value.present?

      # wait for the other process if a last known value isn't there
      if key.present?
        return time('wait.run', tags: tags) do
          wait_for_new_value(keyspace, options, tags)
        end
      end

      # At this point, there's no key, value, last known key, or last known value.
      # A block wasn't given or couldn't create a non-nil value making it
      # impossible to do anything else, so bail
      if !key.present?
        metrics(:increment, 'no-key.give-up')
        log(:warn, "Giving up fetching cache keyspace for root `#{keyspace.root}`. No key could be generated.")
      end
      nil
    end

    protected

    def generate_and_store(keyspace, options, tags)
      generate_ttl_ms = option(:generate_ttl_ms, options, DEFAULT_GENERATE_TIME_MS).to_f / 1000
      if @timestamp_manager.lock(keyspace, generate_ttl_ms, options)
        lmt = Time.now
        new_value = yield

        if new_value.nil?
          # let another thread try right away
          @timestamp_manager.unlock(keyspace)
          metrics(:increment, 'generate.nil', tags: tags)
          log(:warn, "Generator for #{keyspace.key} returned nil. Aborting new cache value.")
          return nil
        end

        new_key = @timestamp_manager.next_key(keyspace, lmt)
        @storage.set(new_key, new_value, options)
        @timestamp_manager.promote(keyspace, last_known_key: new_key, timestamp: lmt)

        metrics(:increment, 'generate.current-thread', tags: tags)
        log(:debug, "Generating new value for `#{new_key}`")

        return new_value
      end

      metrics(:increment, 'generate.other-thread', tags: tags)
      nil
    end

    def last_known_value(keyspace, options, tags)
      lkk = @timestamp_manager.last_known_key(keyspace)

      if lkk.present?
        lkv = @storage.read(lkk, options)
        # even if the last_known_key is present, the value at the
        # last known key may have expired
        if !lkv.nil?
          metrics(:increment, 'last-known-value.present', tags: tags)
          log(:debug, "Read value from last known value key: '#{lkk}'")
          return lkv
        end

        metrics(:increment, 'last-known-value.nil', tags: tags)
      else
        metrics(:increment, 'last-known-value.not-present', tags: tags)
      end

      nil
    end

    def wait_for_new_value(keyspace, options, tags)
      max_retries = option(:max_retries, options, DEFAULT_MAX_RETRIES)
      max_retries.times do |attempt|
        metrics_tags = tags.clone.push("attempt:#{attempt}")
        metrics(:increment, 'wait.attempt', tags: metrics_tags)

        # the duration is given a random element in order to stagger retry across many processes
        backoff_duration_ms = BACKOFF_DURATION_MS + rand(15)
        backoff_duration_ms = option(:backoff_duration_ms, options, backoff_duration_ms)
        sleep((backoff_duration_ms.to_f / 1000) * attempt)

        # re-fetch the key each time, to make sure we're actually getting the latest key with the correct LMT
        key = @timestamp_manager.current_key(keyspace)
        value = @storage.read(key, options)
        if !value.nil?
          metrics(:increment, 'wait.present', tags: metrics_tags)
          return value
        end
      end

      metrics(:increment, 'wait.give-up')
      log(:warn, "Giving up waiting. Exceeded max retries (#{max_retries}) for root #{keyspace.root}.")
      nil
    end

    def option(key, options, default=nil)
      options[key] || @default_options[key] || default
    end

    def log(method, *args)
      @logger.send(method, *args) if @logger.present?
    end

    def metrics(method, *args)
      @metrics.send(method, *args) if @metrics.present?
    end

    def time(*args, &blk)
      if @metrics.present?
        @metrics.time(*args, &blk)
      else
        yield
      end
    end
  end

end
