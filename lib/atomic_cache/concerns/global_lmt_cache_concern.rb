# frozen_string_literal: true

require 'active_support/core_ext/object'
require 'active_support/concern'
require_relative '../atomic_cache_client'
require_relative '../default_config'

module AtomicCache

  # this concern provides a single LMT for the whole model
  module GlobalLMTCacheConcern
    extend ActiveSupport::Concern

    ATOMIC_CACHE_CONCERN_MUTEX = Mutex.new

    class_methods do

      def atomic_cache
        init_atomic_cache
        @atomic_cache
      end

      def cache_version(version)
        ATOMIC_CACHE_CONCERN_MUTEX.synchronize do
          @atomic_cache_version = version
        end
      end

      def cache_class(kls)
        ATOMIC_CACHE_CONCERN_MUTEX.synchronize do
          @atomic_cache_class = kls
        end
      end

      def cache_key_storage(storage)
        ATOMIC_CACHE_CONCERN_MUTEX.synchronize do
          @atomic_cache_key_storage = storage
        end
      end

      def cache_value_storage(storage)
        ATOMIC_CACHE_CONCERN_MUTEX.synchronize do
          @atomic_cache_value_storage = storage
        end
      end

      def default_cache_class
        self.to_s.downcase
      end

      def cache_keyspace(*ks)
        init_atomic_cache
        @default_cache_keyspace.child(ks)
      end

      def expire_cache(at=Time.now)
        init_atomic_cache
        @timestamp_manager.last_modified_time = at
      end

      def last_modified_time
        init_atomic_cache
        @timestamp_manager.last_modified_time
      end

      private

      def init_atomic_cache
        return if @atomic_cache.present?
        ATOMIC_CACHE_CONCERN_MUTEX.synchronize do
          cache_class = @atomic_cache_class || default_cache_class
          prefix = [cache_class]
          prefix.unshift(DefaultConfig.instance.namespace) if DefaultConfig.instance.namespace.present?
          prefix.push("v#{@atomic_cache_version}") if @atomic_cache_version.present?
          @default_cache_keyspace = Keyspace.new(namespace: prefix, root: cache_class)

          @timestamp_manager = LastModTimeKeyManager.new(
            keyspace: @default_cache_keyspace,
            storage: @atomic_cache_key_storage || DefaultConfig.instance.key_storage,
            timestamp_formatter: DefaultConfig.instance.timestamp_formatter,
          )

          @atomic_cache = AtomicCacheClient.new(
            default_options: DefaultConfig.instance.default_options,
            logger: DefaultConfig.instance.logger,
            metrics: DefaultConfig.instance.metrics,
            timestamp_manager: @timestamp_manager,
            storage: @atomic_cache_value_storage || DefaultConfig.instance.cache_storage
          )
        end
      end
    end

    def atomic_cache
      self.class.atomic_cache
    end

    def cache_keyspace(ns)
      self.class.cache_keyspace(ns)
    end

    def expire_cache(at=Time.now)
      self.class.expire_cache(at)
    end

    def last_modified_time
      self.class.last_modified_time
    end

  end
end
