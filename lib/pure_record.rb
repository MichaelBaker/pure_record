module PureRecord
  UnloadedAssociationError = Class.new StandardError

  Create = Struct.new(:pure_instance, :options)
  Update = Struct.new(:pure_instance, :options)
  Delete = Struct.new(:pure_instance, :options)

  def self.purify(record, options={})
    attrs = record.attributes.slice(*record.class.pure_class.attributes)
    attrs = attrs.merge(options: {already_persisted: !record.new_record?})

    # if options[:all_associations]
    #   attrs = attrs.merge(loaded_associations: record.class.pure_class.associations.each_with_object({}) do |assoc, hash|
    #     loaded_assoc = send(assoc)
    #     if loaded_assoc.respond_to?(:map)
    #       hash[assoc] = loaded_assoc.map { |a| a.pure(options) }
    #     else
    #       hash[assoc] = loaded_assoc.pure(options)
    #     end
    #     hash
    #   end)
    # end

    record.class.pure_class.new(attrs)
  end

  def self.impurify(record)
    instance = record.class.active_record_class.new
    record.class.attributes.each do |attr|
      instance.send("#{attr}=", record.send(attr))
    end
    instance.instance_variable_set("@new_record", !record.already_persisted?)
    instance
  end


  class PureClass
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


    def already_persisted?
      @already_persisted
    end

    def valid?
      PureRecord.impurify(self).valid?
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

    attributes   = target_class.columns.map(&:name)
    associations = target_class.reflect_on_all_associations.map(&:name)

    pure_class = Class.new PureClass do
      self.attributes          = attributes
      self.associations        = associations
      self.active_record_class = target_class

      attr_accessor *attributes

      associations.each do |assoc|
        define_method assoc do
          if loaded_associations.has_key?(assoc)
            loaded_associations[assoc]
          else
            raise UnloadedAssociationError.new("You tried to access association #{assoc} on #{self.class.name}, but that association wasn't loaded when the pure record was constructed. You might want to use the 'all_associations: true' or 'associations: { #{assoc}: true }' options when calling 'pure'.")
          end
        end
      end
    end

    class << target_class
      attr_accessor :pure_class
    end

    target_class.pure_class = pure_class

    name_without_namespace = target_class.name.split('::').last
    target_class.const_set "Pure#{name_without_namespace}", pure_class

    pure_class.class_eval(&block)   if block
    target_class.class_eval(&block) if block
  end
end
