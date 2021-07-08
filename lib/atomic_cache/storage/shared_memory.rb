# frozen_string_literal: true

require_relative 'memory'

module AtomicCache
  module Storage

    # A storage adapter which keeps all values in memory, global to all threads
    class SharedMemory < Memory
      STORE = {}
      SEMAPHORE = Mutex.new

      @enforce_ttl = true
      class << self
        attr_accessor :enforce_ttl
      end

      def add(raw_key, new_value, ttl, user_options={})
        if self.class.enforce_ttl
          super(raw_key, new_value, ttl, user_options)
        else
          store_op(raw_key, user_options) do |key, options|
            write(key, new_value, ttl, user_options)
          end
        end
      end

      def self.reset
        STORE.clear
      end

      def self.store
        STORE
      end

      def reset
        self.class.reset
      end

      def store
        STORE
      end

      def store_op(key, user_options={})
        normalized_key = key.to_sym
        SEMAPHORE.synchronize do
          yield(normalized_key, user_options)
        end
      end

    end
  end
end
