# frozen_string_literal: true

require 'singleton'

module AtomicCache
  class DefaultConfig
    include Singleton

    CONFIG_MUTEX = Mutex.new

    FLOAT_TIME_FORMATTER = Proc.new { |time| time.to_f }
    TIMESTAMP_SEC_FORMATTER = Proc.new { |time| time.to_i }
    TIMESTAMP_MS_FORMATTER = Proc.new { |time| (time.to_f * 1000).to_i }
    ISO8601_FORMATTER = Proc.new { |time| time.iso8601 }
    DEFAULT_TIME_FORMATTER = FLOAT_TIME_FORMATTER
    DEFAULT_SEPARATOR = ':'

    # [required] config
    attr_accessor :key_storage # storage adapter instance for keys
    attr_accessor :cache_storage # storage adapter instance for cached values

    # [optional] config
    attr_accessor :default_options # default options for all fetch requests
    attr_accessor :namespace
    attr_accessor :logger
    attr_accessor :metrics
    attr_accessor :timestamp_formatter
    attr_accessor :separator

    def initialize
      reset
    end

    # Change all configured values back to default
    def reset
      @cache_client = nil
      @default_options = {}
      @namespace = nil
      @logger = nil
      @metrics = nil
      @timestamp_formatter = DEFAULT_TIME_FORMATTER
      @separator = DEFAULT_SEPARATOR
    end

    # Change all configured values back to default
    def self.reset
      self.instance.reset
    end

    # Quickly configure config singleton instance
    # @yield mutate config
    # @yieldparam [AtomicCache::DefaultConfig] config instance
    def self.configure
      if block_given?
        manager = self.instance
        CONFIG_MUTEX.synchronize do
          yield(manager)
        end
      end
    end
  end
end
