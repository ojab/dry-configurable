# frozen_string_literal: true

require 'concurrent/map'

require 'dry/equalizer'

require 'dry/configurable/constants'
require 'dry/configurable/errors'

module Dry
  module Configurable
    # Config exposes setting values through a convenient API
    #
    # @api public
    class Config
      include Dry::Equalizer(:values)

      # @api private
      attr_reader :settings

      # @api private
      attr_reader :resolved

      # @api private
      def initialize(settings)
        @settings = settings.dup
        @resolved = Concurrent::Map.new
      end

      # Get config value by a key
      #
      # @param [String,Symbol] name
      #
      # @return Config value
      def [](name)
        raise ArgumentError, "+#{name}+ is not a setting name" unless settings.key?(name)

        settings[name].value
      end

      # Set config value.
      # Note that finalized configs cannot be changed.
      #
      # @param [String,Symbol] name
      # @param [Object] value
      def []=(name, value)
        public_send(:"#{name}=", value)
      end

      # Dump config into a hash
      #
      # @return [Hash]
      #
      # @api public
      def values
        settings
          .map { |setting| [setting.name, setting.value] }
          .map { |key, value| [key, value.is_a?(self.class) ? value.to_h : value] }
          .to_h
      end
      alias_method :to_h, :values
      alias_method :to_hash, :values

      # @api private
      def finalize!
        settings.freeze
        freeze
      end

      # @api private
      def pristine
        self.class.new(settings.pristine)
      end

      # @api private
      def respond_to_missing?(meth, include_private = false)
        super || settings.key?(resolve(meth))
      end

      private

      # @api private
      def method_missing(meth, *args)
        setting = settings[resolve(meth)]

        super unless setting

        if setting.writer?(meth)
          raise FrozenConfig, 'Cannot modify frozen config' if frozen?

          settings << setting.with(input: args[0])
        else
          setting.value
        end
      end

      # @api private
      def resolve(meth)
        resolved.fetch(meth) { resolved[meth] = meth.to_s.tr('=', '').to_sym }
      end

      # @api private
      def initialize_copy(source)
        super
        @settings = source.settings.dup
      end
    end
  end
end
