require_relative '../utils/page_identifier'

module Howitzer
  module Utils
    module PageValidator
      WrongOptionError = Class.new(StandardError)
      NoValidationError = Class.new(StandardError)
      UnknownValidationName = Class.new(StandardError)
      @validations = {}

      ##
      #
      # Returns validation list
      #
      # @return [Hash]
      #
      def self.validations
        @validations
      end

      def self.included(base)  #:nodoc:
        base.extend(ClassMethods)
      end

      ##
      #
      # Checks that correct page has been loaded
      #
      # @raise  [Howitzer::Utils::PageValidator::NoValidationError]   If no validation was specified
      #
      def check_correct_page_loaded
        if validations.nil?
          if old_url_validation_present?
            self.class.validates :url, pattern: self.class.const_get("URL_PATTERN")
            puts "[Deprecated] Old style page validation is using. Please use new style:\n\t validates :url, pattern: URL_PATTERN"
          else
            raise NoValidationError, "No any page validation was found for '#{self.class.name}' page"
          end
        end
        validations.each {|(_, validation)| validation.call(self)}
      end

      private

      def validations
        PageValidator.validations[self.class.name]
      end

      def old_url_validation_present?
        self.class.const_defined?("URL_PATTERN")
      end

      module ClassMethods

        ##
        #
        # Adds validation to validation list
        #
        # @param [Symbol or String] name                                    Which validation type. Possible values [:url, :element_presence, :title]
        # @option options [Hash]                                            Validation options
        #    :pattern => [Regexp]                                             For :url and :title validation types
        #    :locator => [String]                                             For :element_presence (Existing locator name)
        # @raise  [Howitzer::Utils::PageValidator::UnknownValidationName]   If unknown validation type was passed
        #
        def validates(name, options)
          raise TypeError, "Expected options to be Hash, actual is '#{options.class}'" unless options.class == Hash
          PageValidator.validations[self.name] ||= {}
          PageIdentifier.validations[self.name] ||= {}
          case name.to_sym
            when :url
              validate_url options
            when :element_presence
              validate_element options
            when :title
              validate_title options
            else
              raise UnknownValidationName, "unknown '#{name}' validation name"
          end
        end

        private

        def validate_url(options)
          pattern = options[:pattern] || options["pattern"]
          raise WrongOptionError, "Please specify ':pattern' option as Regexp object" if pattern.nil? || !pattern.is_a?(Regexp)
          PageValidator.validations[self.name][:url] = lambda { |web_page| web_page.wait_for_url(pattern) }
          PageIdentifier.validations[self.name][:url] = lambda { |url| pattern === url }
        end

        def validate_element(options)
          locator = options[:locator] || options["locator"]
          raise WrongOptionError, "Please specify ':locator' option as one of page locator names" if locator.nil? || locator.empty?
          PageValidator.validations[self.name][:element_presence] = lambda { |web_page| web_page.find_element(locator) }
        end

        def validate_title(options)
          pattern = options[:pattern] || options["pattern"]
          raise WrongOptionError, "Please specify ':pattern' option as Regexp object" if pattern.nil? || !pattern.is_a?(Regexp)
          PageValidator.validations[self.name][:title] = lambda { |web_page| web_page.wait_for_title(pattern) }
          PageIdentifier.validations[self.name][:title] = lambda { |title| pattern === title }
        end

      end
    end

  end
end