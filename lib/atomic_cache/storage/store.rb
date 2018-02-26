# frozen_string_literal: true

require_relative 'memory'

module AtomicCache
  module Storage

    class Store

      # @abstract (String, Object, Integer, Hash) -> Boolean
      # ttl is in millis
      # operation must be atomic
      # returns true when the key doesn't exist and was written successfully
      # returns false in all other cases
      def add(key, new_value, ttl, user_options); raise NotImplementedError end

      # @abstract (String, Hash) -> String
      # return the `value` at `key`
      def read(key, user_options); raise NotImplementedError end

      # @abstract (String, Object) -> Boolean
      # returns true if it succeeds; false otherwise
      def set(key, new_value, user_options); raise NotImplementedError end

      # @abstract (String) -> Boolean
      # returns true if it succeeds; false otherwise
      def delete(key, user_options); raise NotImplementedError end

      protected

      def marshal(value, user_options={})
        return value if user_options[:raw]
        Marshal.dump(value)
      end

      def unmarshal(value, user_options={})
        return value if user_options[:raw]
        Marshal.load(value)
      end

    end
  end
end
