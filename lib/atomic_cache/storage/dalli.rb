# frozen_string_literal: true

require 'forwardable'
require_relative 'store'

module AtomicCache
  module Storage

    # A light wrapper over the Dalli client
    class Dalli < Store
      extend Forwardable

      def_delegators :@dalli_client, :delete

      def initialize(dalli_client)
        @dalli_client = dalli_client
      end

      def add(key, new_value, ttl, user_options={})
        opts = user_options.clone
        opts[:raw] = true

        # dalli expects time in seconds
        # https://github.com/petergoldstein/dalli/blob/b8f4afe165fb3e07294c36fb1c63901b0ed9ce10/lib/dalli/client.rb#L27
        # TODO: verify this unit is being treated correctly through the system
        !!@dalli_client.add(key, new_value, ttl, opts)
      end

      def read(key, user_options={})
        @dalli_client.get(key, user_options)
      end

      def set(key, value, user_options={})
        ttl = user_options[:ttl]
        user_options.delete(:ttl)
        @dalli_client.set(key, value, ttl, user_options)
      end

    end
  end
end
