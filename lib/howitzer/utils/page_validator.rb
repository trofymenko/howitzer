require 'howitzer/exceptions'

module Howitzer
  module Utils
    # This module combines page validation methods
    module PageValidator
      @validations = {}

      def self.included(base) #:nodoc:
        base.extend(ClassMethods)
      end

      ##
      #
      # Returns validation list
      #
      # @return [Hash]
      #
      def self.validations
        @validations
      end

      ##
      #
      # Returns page list
      #
      # @return [Array]
      #
      def self.pages
        @pages ||= []
      end

      ##
      # Check if any validations are defined, if no, tries to find old style, else raise error
      #
      # @raise  [Howitzer::NoValidationError] If no one validation is defined for page
      #

      def check_validations_are_defined!
        return unless validations.nil?

        log.error Howitzer::NoValidationError, "No any page validation was found for '#{self.class.name}' page"
      end

      private

      def validations
        PageValidator.validations[self.class.name]
      end

      # This module holds page validation class methods
      module ClassMethods
        ##
        #
        # Adds validation to validation list
        #
        # @param [Symbol or String] name       Which validation type. Possible values [:url, :element_presence, :title]
        # @option options [Hash]                      Validation options
        #    :pattern => [Regexp]                     For :url and :title validation types
        #    :locator => [String]                     For :element_presence (Existing locator name)
        # @raise  [Howitzer::UnknownValidationError]  If unknown validation type was passed
        #
        def validate(name, options)
          log.error TypeError, "Expected options to be Hash, actual is '#{options.class}'" unless options.class == Hash
          PageValidator.validations[self.name] ||= {}
          validate_by_type(name, options)
        end

        ##
        # Check whether page is opened or no
        #
        # @raise  [Howitzer::NoValidationError] If no one validation is defined for page
        #
        # *Returns:*
        # * +boolean+
        #

        def opened?
          validation_list = PageValidator.validations[name]
          if validation_list.blank?
            log.error Howitzer::NoValidationError, "No any page validation was found for '#{name}' page"
          else
            !validation_list.any? { |(_, validation)| !validation.call(self) }
          end
        end

        ##
        #
        # Finds all matched pages which are satisfy of defined validations
        #
        # *Returns:*
        # * +array+ - page names
        #

        def matched_pages
          PageValidator.pages.select(&:opened?)
        end

        private

        def validate_element(options)
          locator = options[:locator] || options['locator']
          if locator.nil? || locator.empty?
            log.error Howitzer::WrongOptionError, "Please specify ':locator' option as one of page locator names"
          end
          PageValidator.validations[name][:element_presence] = ->(web_page) { web_page.first_element(locator) }
        end

        def pattern_from_options(options)
          pattern = options[:pattern] || options['pattern']
          if pattern.nil? || !pattern.is_a?(Regexp)
            log.error Howitzer::WrongOptionError, "Please specify ':pattern' option as Regexp object"
          end
          pattern
        end

        def validate_by_pattern(name, options)
          pattern = pattern_from_options(options)
          PageValidator.validations[self.name][name] = lambda do |web_page|
            method_name = name == :url ? :current_url : name
            pattern === web_page.send(method_name)
          end
        end

        def validate_by_type(type, options)
          case type.to_s.to_sym
            when :url
              validate_by_pattern(:url, options)
            when :element_presence
              validate_element(options)
            when :title
              validate_by_pattern(:title, options)
            else
              log.error Howitzer::UnknownValidationError, "unknown '#{type}' validation type"
          end
        end
      end
    end
  end
end
