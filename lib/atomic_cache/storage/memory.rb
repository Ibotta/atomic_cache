# frozen_string_literal: true

require_relative 'store'

module AtomicCache
  module Storage

    # An abstract storage adapter which keeps all values in memory
    class Memory < Store

      # @abstract implement returning a Hash of the in-memory representation
      def store; raise NotImplementedError end

      # @abstract implement performing an operation on the store
      def store_op(key, user_options=nil); raise NotImplementedError end

      def add(raw_key, new_value, ttl, user_options=nil)
        store_op(raw_key, user_options) do |key, options|
          return false if store.has_key?(key)
          write(key, new_value, ttl, user_options)
        end
      end

      def read(raw_key, user_options=nil)
        store_op(raw_key, user_options) do |key, options|
          entry = store[key]
          return nil unless entry.present?

          unmarshaled = Marshal.load(entry[:value])
          return unmarshaled if entry[:ttl].nil? or entry[:ttl] == false

          life = Time.now - entry[:written_at]
          if (life >= entry[:ttl])
            store.delete(key)
            nil
          else
            unmarshaled
          end
        end
      end

      def set(raw_key, new_value, user_options=nil)
        store_op(raw_key, user_options) do |key, options|
          write(key, new_value, options[:expires_in], user_options)
        end
      end

      def delete(raw_key)
        store_op(raw_key) do |key, options|
          store.delete(key)
          true
        end
      end

      def write(key, value, ttl=nil, user_options=nil)
        store[key] = {
          value: marshal(value, user_options),
          ttl: ttl || false,
          written_at: Time.now
        }
        true
      end
    end
  end
end
