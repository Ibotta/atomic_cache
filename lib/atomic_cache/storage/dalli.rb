# frozen_string_literal: true

require 'forwardable'
require_relative 'store'

module AtomicCache
  module Storage

    # A light wrapper over the Dalli client
    class Dalli < Store
      extend Forwardable

      ADD_SUCCESS = 'STORED'
      ADD_UNSUCCESSFUL = 'NOT_STORED'
      ADD_EXISTS = 'EXISTS'

      def_delegators :@dalli_client, :delete

      def initialize(dalli_client)
        @dalli_client = dalli_client
      end

      def add(key, new_value, ttl, user_options=nil)
        opts = user_options&.clone || {}
        opts[:raw] = true

        # dalli expects time in seconds
        # https://github.com/petergoldstein/dalli/blob/b8f4afe165fb3e07294c36fb1c63901b0ed9ce10/lib/dalli/client.rb#L27
        # TODO: verify this unit is being treated correctly through the system
        response = @dalli_client.add(key, new_value, ttl, opts)
        response.start_with?(ADD_SUCCESS)
      end

      def read(key, user_options=nil)
        user_options ||= {}
        raw = @dalli_client.read(key, user_options)
        unmarshal(raw, user_options)
      end

      def set(key, value, user_options=nil)
        user_options ||= {}
        raw = marshal(value, user_options)
        @dalli_client.set(key, raw, user_options)
      end

    end
  end
end
