module PureRecord
  module Helpers
    def self.generate_pure_class(active_record_class, attributes, associations)
      Class.new PureClass do
        self.attributes          = attributes
        self.associations        = associations
        self.active_record_class = active_record_class

        attr_accessor *attributes

        associations.each do |assoc|
          define_method assoc do
            if loaded_associations.has_key?(assoc)
              loaded_associations[assoc]
            else
              raise UnloadedAssociationError.new("You tried to access association #{assoc} on #{self.class.name}, but that association wasn't loaded when the pure record was constructed. You might want to use the 'includes: #{assoc}' option when querying for #{self.class.active_record_class.name}.")
            end
          end
        end
      end
    end

    def self.one_or_many(record_s, method_name, valid_class, &block)
      if !record_s.kind_of?(Array) && !record_s.kind_of?(valid_class)
        raise ArgumentError.new("You cannot use '#{method_name}' with #{record_s.class.name}. '#{method_name}' can only be used on an instance of #{valid_class.name} or an array of instances of #{valid_class.name}.")
      end

      is_collection = record_s.kind_of?(Array)
      records       = is_collection ? record_s : [record_s]
      results       = block.call(records)
      is_collection ? results : results.first
    end
  end
end
