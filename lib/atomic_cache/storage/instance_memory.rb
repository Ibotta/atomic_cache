# frozen_string_literal: true

require_relative 'memory'

module AtomicCache
  module Storage

    # A storage adapter which keeps all values in memory, private to the instance
    class InstanceMemory < Memory

      def initialize(*args)
        reset
        super(*args)
      end

      def reset
        @store = {}
      end

      def store
        @store
      end

      def store_op(key, user_options={})
        if !key.present?
          desc = if key.nil? then 'Nil' else 'Empty' end
          raise ArgumentError.new("#{desc} key given for storage operation") unless key.present?
        end

        normalized_key = key.to_sym
        yield(normalized_key, user_options)
      end

    end
  end
end
