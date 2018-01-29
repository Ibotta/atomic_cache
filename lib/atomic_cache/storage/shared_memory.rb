# frozen_string_literal: true

require_relative 'memory'

module AtomicCache
  module Storage

    # A storage adapter which keeps all values in memory, global to all threads
    class SharedMemory < Memory
      STORE = {}
      SEMAPHORE = Mutex.new

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

      def store_op(key, user_options=nil)
        normalized_key = key.to_sym
        user_options ||= {}

        SEMAPHORE.synchronize do
          yield(normalized_key, user_options)
        end
      end

    end
  end
end
