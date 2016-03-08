module PureRecord
  class PureClass
    UnloadedAssociationError = Class.new StandardError

    attr_reader :loaded_associations

    class << self
      attr_accessor :attributes, :associations, :active_record_class
    end

    def self.join_attrs(attrs)
      attrs.map {|a| "'#{a}'" }.join(", ")
    end

    def initialize(attrs={})
      attrs                = attrs.dup
      options              = attrs.delete(:options) || {}
      @already_persisted   = options.fetch(:already_persisted, false)
      @loaded_associations = attrs.delete(:loaded_associations) || {}
      attrs                = attrs.stringify_keys
      extra_keys           = attrs.keys - self.class.attributes

      if extra_keys.any? && !options[:ignore_extra_attrs]
        raise ArgumentError.new("#{self.class.name} was initialized with invalid attributes #{self.class.join_attrs(extra_keys)}. The only valid attributes for #{self.class.name} are #{self.class.join_attrs(self.class.attributes)}")
      end

      self.class.attributes.each do |attr|
        instance_variable_set("@#{attr}", attrs[attr])
      end
    end

    def add_associations(assoc_hash)
      @loaded_associations.merge!(assoc_hash)
    end

    def already_persisted?
      @already_persisted
    end

    def fetch_association(assoc_name)
      if loaded_associations.has_key?(assoc_name)
        loaded_associations[assoc_name]
      else
        raise UnloadedAssociationError.new("You tried to access association #{assoc_name} on #{self.class.name}, but that association wasn't loaded when the pure record was constructed. You might want to use the '.includes(:#{assoc_name})' method when querying for #{self.class.active_record_class.name}.")
      end
    end

    def method_missing(method_name, *args, &block)
      if self.class.active_record_class.method_defined?(method_name)
        raise NoMethodError.new("You tried to call '#{method_name}' on an instance of #{self.class.name}. '#{method_name}' is not a pure method and can only be called on instances of #{self.class.active_record_class.name}.")
      else
        super
      end
    end
  end
end
