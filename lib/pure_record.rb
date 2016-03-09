require 'active_record'
require 'pure_record/pure_class'
require 'pure_record/actions'

module PureRecord
  def self.Create(*args)
    PureRecord::Actions::Create.new(*args)
  end

  def self.Update(*args)
    PureRecord::Actions::Update.new(*args)
  end

  def self.Delete(*args)
    PureRecord::Actions::Delete.new(*args)
  end

  def self.generate_pure_class(active_record_class)
    if !active_record_class.ancestors.include?(ActiveRecord::Base)
      raise ArgumentError.new("Invalid argument to 'pure'. #{active_record_class.name} is not a subclass of ActiveRecord::Base, but it very well should be.")
    end

    Class.new PureClass do
      self.attributes          = active_record_class.columns.map(&:name)
      self.associations        = active_record_class.reflect_on_all_associations.map(&:name)
      self.active_record_class = active_record_class

      attr_accessor *attributes

      associations.each do |assoc_name|
        define_method(assoc_name) { fetch_association(assoc_name) }
      end
    end
  end

  def self.purify(record_s)
    cached_purify(record_s, {})
  end

  def self.impurify(record_s)
    cached_impurify(record_s, {})
  end

  def self.validate(record_s)
    Array(record_s).all?  do |record|
      impurify(record).valid?
    end
  end

  private

  def self.cached_purify(record_s, association_cache)
    one_or_many(record_s, 'purify') do |records|
      records.map do |record|
        if record.kind_of?(PureRecord::PureClass)
          return record.dup
        end

        if !record.class.respond_to?(:pure_class)
          raise ArgumentError.new("#{record.class.name} does not have a pure class. Perhaps you forgot to define the 'pure_class' method for #{record.class.name}.")
        end

        if association_cache[record.object_id]
          return association_cache[record.object_id]
        end

        attrs       = record.attributes.slice(*record.class.pure_class.attributes)
        attrs       = attrs.merge(options: {already_persisted: !record.new_record?})
        pure_record = record.class.pure_class.new(attrs)
        association_cache[record.object_id] = pure_record

        assoc_hash = record.class.pure_class.associations.each_with_object({}) do |assoc_name, hash|
          assoc = record.association(assoc_name)
          if assoc.loaded? && assoc.target
            hash[assoc_name] = cached_purify(assoc.target, association_cache)
          elsif assoc.loaded?
            hash[assoc_name] = nil
          end
        end

        pure_record.add_associations(assoc_hash)
        pure_record
      end
    end
  end

  def self.cached_impurify(record_s, association_cache)
    one_or_many(record_s, 'impurify') do |records|
      records.map do |record|
        if record.kind_of?(ActiveRecord::Base)
          return impurify(purify(record))
        end

        if association_cache[record.object_id]
          return association_cache[record.object_id]
        end

        instance = record.class.active_record_class.new
        association_cache[record.object_id] = instance

        record.class.attributes.each do |attr|
          instance.send("#{attr}=", record.send(attr))
        end

        record.loaded_associations.each do |assoc_name, pure_associations|
          assoc        = instance.association(assoc_name).loaded!
          impure_assoc = pure_associations ? cached_impurify(pure_associations, association_cache) : nil
          instance.association(assoc_name).loaded!
          instance.association(assoc_name).writer(impure_assoc)
        end

        instance.instance_variable_set("@new_record", !record.already_persisted?)
        instance
      end
    end
  end


  ValidClasses = [Array, ActiveRecord::Base, PureRecord::PureClass]

  def self.one_or_many(record_s, method_name, &block)
    if !ValidClasses.any? { |klass| record_s.kind_of?(klass) }
      raise ArgumentError.new("You cannot use '#{method_name}' with #{record_s.class.name}. '#{method_name}' can only be used on an instance of ActiveRecord::Base, PureRecord::PureClass, or Array.")
    end

    is_collection = record_s.kind_of?(Array)
    records       = is_collection ? record_s : [record_s]
    results       = block.call(records)
    is_collection ? results : results.first
  end
end
