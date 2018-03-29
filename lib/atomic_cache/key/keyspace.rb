# frozen_string_literal: true

require 'murmurhash3'
require 'active_support/concern'
require 'active_support/core_ext/object'
require 'active_support/core_ext/hash'
require_relative '../default_config'

module AtomicCache
  class Keyspace

    DEFAULT_SEPARATOR = ':'
    LOCK_VALUE = 1
    PRIMITIVE_CLASSES = [Numeric, String, Symbol]

    attr_reader :namespace, :root

    # @param namespace [Object, Array<Object>] segment(s) with which to prefix the keyspace
    # @param root [Object] logical 'root' or primary identifier for this keyspace
    # @param separator [String] character or string to separate keyspace segments
    # @param timestamp_formatter [Proc] function to turn Time -> String
    def initialize(namespace:, root: nil, separator: nil, timestamp_formatter: nil)
      @timestamp_formatter = timestamp_formatter || DefaultConfig.instance.timestamp_formatter
      @separator = separator || DefaultConfig.instance.separator
      @namespace = []
      @namespace = normalize_segments(namespace) if namespace.present?
      @root = root || @namespace.last
    end

    # Create a new Keyspace, extending the namespace with the given segments and
    # retaining this keyspace's root and separator
    #
    # @param namespace [Array<Object>] segments to concat onto this keyspace
    # @return [AtomicCache::Keyspace] child keyspace
    def child(namespace)
      throw ArgumentError.new("Prefix must be an Array but was #{namespace.class}") unless namespace.is_a?(Array)
      joined_namespacees = @namespace.clone.concat(namespace)
      self.class.new(namespace: joined_namespacees)
    end

    # Get a string key for this keyspace, optionally suffixed by the given value
    #
    # @param suffix [String, Symbol, Numeric] an optional suffix
    # @return [String] a key
    def key(suffix=nil)
      flattened_key(suffix)
    end

    def last_mod_time_key
      @last_mod_time_key ||= flattened_key('lmt')
    end

    def lock_key
      @lock_key ||= flattened_key('lock')
    end

    # the key the last_known_key is stored at, thus key key.
    def last_known_key_key
      @last_known_key ||= flattened_key('lkk')
    end

    protected

    def flattened_key(suffix=nil)
      segments = @namespace
      segments = @namespace.clone.push(suffix) if suffix.present?
      segments.join(@separator)
    end

    def normalize_segments(segments)
      if segments.is_a? Array
        segments.map { |seg| expand_segment(seg) }
      elsif segments.nil?
        []
      else
        [expand_segment(segments)]
      end
    end

    def expand_segment(segment)
      case segment
        when Symbol, String, Numeric
          segment
        when DateTime, Time, Date
          @timestamp_formatter.call(segment)
        else
          hexhash(segment)
      end
    end

    def hexhash(segment)
      # if the segment is sortable, sort it before hashing so that collections
      # come out with the same hash
      segment = segment.sort if segment.respond_to?(:sort)
      MurmurHash3::V128.str_hash(Marshal.dump(segment)).pack('L*').unpack('H*').first
    end
  end
end
