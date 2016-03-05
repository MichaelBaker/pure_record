module PureRecord
  Create = Struct.new(:pure_instance, :options)
  Update = Struct.new(:pure_instance, :options)
  Delete = Struct.new(:pure_instance, :options)

  class PureClass
    def self.join_attrs(attrs)
      attrs.map {|a| "'#{a}'" }.join(", ")
    end

    def initialize(attrs={})
      options    = attrs.delete(:options) || {}
      attrs      = attrs.stringify_keys
      extra_keys = attrs.keys - self.class.attributes

      if extra_keys.any? && !options[:ignore_extra_attrs]
        raise ArgumentError.new("#{self.class.name} was initialized with invalid attributes #{self.class.join_attrs(extra_keys)}. The only valid attributes for #{self.class.name} are #{self.class.join_attrs(self.class.attributes)}")
      end

      self.class.attributes.each do |attr|
        instance_variable_set("@#{attr}", attrs[attr])
      end
    end

    def valid?
      impure.valid?
    end

    def impure
     instance = self.class.active_record_class.new
     (self.class.attributes - ['already_persisted']).each do |attr|
       instance.send("#{attr}=", self.send(attr))
     end
     instance.instance_variable_set("@new_record", !already_persisted)
     instance
    end

    def method_missing(method_name, *args, &block)
      if self.class.active_record_class.method_defined?(method_name)
        raise NoMethodError.new("You tried to call '#{method_name}' on an instance of #{self.class.name}. '#{method_name}' is not a pure method and can only be called on instances of #{self.class.active_record_class.name}.")
      else
        super
      end
    end
  end

  def self.create_pure_class(target_class, &block)
    if !const_defined?('ActiveRecord::Base') || !target_class.ancestors.include?(ActiveRecord::Base)
      raise ArgumentError.new("Invalid argument to 'pure'. #{target_class.name} is not a subclass of ActiveRecord::Base, but it very well should be.")
    end

    attributes = target_class.columns.map(&:name)

    pure_class = Class.new PureClass do
      attr_accessor *attributes
      attr_reader :already_persisted

      class << self
        attr_accessor :attributes, :active_record_class
      end

      self.attributes          = attributes + ['already_persisted']
      self.active_record_class = target_class
    end

    class << target_class
      attr_accessor :pure_class
    end

    target_class.pure_class = pure_class
    target_class.include InstanceMethods

    name_without_namespace = target_class.name.split('::').last
    target_class.const_set "Pure#{name_without_namespace}", pure_class

    pure_class.class_eval(&block)
    target_class.class_eval(&block)
  end

  module InstanceMethods
    def pure
      attrs                   = self.attributes.slice(*self.class.pure_class.attributes)
      attrs_with_persistence = attrs.merge(already_persisted: !new_record?)
      self.class.pure_class.new(attrs_with_persistence)
    end
  end
end
