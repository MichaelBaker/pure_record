require 'active_record'
require 'pure_record/pure_class'
require 'pure_record/helpers'
require 'pure_record/actions'

# TODO
# ----
# Make it into a gem
# Do requires correctly
#
# Features
# --------
# Database operations
#
module PureRecord
  UnloadedAssociationError = Class.new StandardError

  def self.Create(*args)
    PureRecord::Actions::Create.new(*args)
  end

  def self.Update(*args)
    PureRecord::Actions::Update.new(*args)
  end

  def self.Delete(*args)
    PureRecord::Actions::Delete.new(*args)
  end

  def self.create_pure_class(active_record_class, &block)
    if !active_record_class.ancestors.include?(ActiveRecord::Base)
      raise ArgumentError.new("Invalid argument to 'pure'. #{active_record_class.name} is not a subclass of ActiveRecord::Base, but it very well should be.")
    end

    attributes   = active_record_class.columns.map(&:name)
    associations = active_record_class.reflect_on_all_associations.map(&:name)
    pure_class   = PureRecord::Helpers.generate_pure_class(active_record_class, attributes, associations)

    class << active_record_class; attr_reader :pure_class; end
    active_record_class.instance_variable_set('@pure_class', pure_class)

    name_without_namespace = active_record_class.name.split('::').last
    active_record_class.const_set("Pure#{name_without_namespace}", pure_class)

    pure_class.class_eval(&block)          if block
    active_record_class.class_eval(&block) if block
  end

  def self.purify(record_s, options={})
    options[:association_cache] ||= {}

    PureRecord::Helpers.one_or_many(record_s, 'purify', ActiveRecord::Base) do |records|
      records.map do |record|
        if !record.class.respond_to?(:pure_class)
          raise ArgumentError.new("#{record.class.name} does not have a pure class. Perhaps you forgot to add PureRecord.create_pure_class(#{record.class.name}) to your model.")
        end

        if options[:association_cache][record.object_id]
          return options[:association_cache][record.object_id]
        end

        attrs       = record.attributes.slice(*record.class.pure_class.attributes)
        attrs       = attrs.merge(options: {already_persisted: !record.new_record?})
        pure_record = record.class.pure_class.new(attrs)
        options[:association_cache][record.object_id] = pure_record

        assoc_hash = record.class.pure_class.associations.each_with_object({}) do |assoc_name, hash|
          assoc = record.association(assoc_name)
          if assoc.loaded? && assoc.target
            hash[assoc_name] = purify(assoc.target, options)
          elsif assoc.loaded?
            hash[assoc_name] = nil
          end
        end

        pure_record.add_associations(assoc_hash)
        pure_record
      end
    end
  end

  def self.impurify(record_s, options={})
    options[:association_cache] ||= {}

    PureRecord::Helpers.one_or_many(record_s, 'impurify', PureRecord::PureClass) do |records|
      records.map do |record|
        if options[:association_cache][record.object_id]
          return options[:association_cache][record.object_id]
        end

        instance = record.class.active_record_class.new
        options[:association_cache][record.object_id] = instance

        record.class.attributes.each do |attr|
          instance.send("#{attr}=", record.send(attr))
        end

        record.loaded_associations.each do |assoc_name, pure_associations|
          assoc        = instance.association(assoc_name).loaded!
          impure_assoc = pure_associations ? impurify(pure_associations, options) : nil
          instance.association(assoc_name).loaded!
          instance.association(assoc_name).writer(impure_assoc)
        end

        instance.instance_variable_set("@new_record", !record.already_persisted?)
        instance
      end
    end
  end

  def self.validate(record_s)
    Array(record_s).all?  do |record|
      impurify(record).valid?
    end
  end
end
