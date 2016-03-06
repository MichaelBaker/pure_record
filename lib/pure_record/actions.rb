# TODO
# ----
# Check for invalid keys

module PureRecord
  module Actions
    class Create
      attr_accessor :pure_record, :table_name, :columns_to_insert, :create_associated

      def initialize(pure_record, options={})
        pure_class  = pure_record.class
        ar_class    = pure_record.class.active_record_class
        all_columns = pure_class.attributes

        self.pure_record       = pure_record
        self.table_name        = ar_class.table_name
        self.create_associated = options[:create_associated]
        self.columns_to_insert = all_columns - [ar_class.primary_key]

        if options[:include_columns]
          self.columns_to_insert = columns_to_insert + options[:include_columns].map(&:to_s)
        end

        if options[:exclude_columns]
          self.columns_to_insert = columns_to_insert - options[:exclude_columns].map(&:to_s)
        end

        if options[:skip_timestamps]
          self.columns_to_insert = columns_to_insert - ['updated_at', 'created_at']
        end
      end

      def attributes_to_insert(current_time:)
        attributes   = []
        ar_class     = pure_record.class.active_record_class

        columns_to_insert.each do |column_name|
          column   = ar_class.columns_hash[column_name]
          sql_type = ar_class.columns_hash[column_name].sql_type.to_s

          value = if %w[updated_at created_at].include?(column_name)
            ar_class.connection.quote(current_time, column)
          else
            ar_class.connection.quote(pure_record.send(column_name), column)
          end

          attributes << { column_name: column_name, value: value, sql_type: sql_type }
        end

        attributes
      end
    end

    class Update
      attr_accessor :pure_record, :table_name, :columns_to_update, :primary_key, :primary_key_value

      def initialize(pure_record, columns_to_update, options={})
        pure_class  = pure_record.class
        ar_class    = pure_record.class.active_record_class

        self.pure_record       = pure_record
        self.table_name        = ar_class.table_name
        self.columns_to_update = columns_to_update.map(&:to_s) + ['updated_at']
        self.primary_key       = ar_class.primary_key
        self.primary_key_value = pure_record.send(primary_key)

        if options[:skip_timestamps]
          self.columns_to_update = columns_to_update - ['updated_at']
        end
      end

      def attributes_to_update(current_time:)
        attributes   = []
        ar_class     = pure_record.class.active_record_class

        columns_to_update.each do |column_name|
          column   = ar_class.columns_hash[column_name]
          sql_type = ar_class.columns_hash[column_name].sql_type.to_s

          value = if column_name == 'updated_at'
            ar_class.connection.quote(current_time, column)
          else
            ar_class.connection.quote(pure_record.send(column_name), column)
          end

          attributes << { column_name: column_name, value: value, sql_type: sql_type }
        end

        attributes
      end
    end

    class Delete
      attr_accessor :pure_record, :table_name, :primary_key, :primary_key_value

      def initialize(pure_record)
        pure_class  = pure_record.class
        ar_class    = pure_record.class.active_record_class

        self.pure_record       = pure_record
        self.table_name        = ar_class.table_name
        self.primary_key       = ar_class.primary_key
        self.primary_key_value = pure_record.send(primary_key)
      end
    end
  end
end
