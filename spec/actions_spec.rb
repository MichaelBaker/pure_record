require 'spec_helper'
require 'pure_record/terse'
require 'pure_record/actions'

RSpec.describe PR::Actions do
  describe PR::Actions::Create do
    it 'generates a data structure that represents a database insert of a given pure record' do
      record = TestRecord::PureTestRecord.new(name: 'Michael', age: 123)
      action = PR.Create(record)
      expect(action.table_name).to        eq('test_records')
      expect(action.columns_to_insert).to match_array(%w[name age updated_at created_at])
    end

    describe 'attributes_to_insert' do
      it 'produces an array of fields to insert' do
        time   = Time.parse('2016-03-06 13:53:20 -0600')
        record = TestRecord::PureTestRecord.new(name: 'Michael', age: 123)
        attrs  = PR.Create(record).attributes_to_insert(current_time: time)
        expect(attrs).to match_array([
          { column_name: 'name',       value: "'Michael'",                    sql_type: 'varchar' },
          { column_name: 'age',        value: '123',                          sql_type: 'integer' },
          { column_name: 'updated_at', value: "'2016-03-06 19:53:20.000000'", sql_type: 'datetime' },
          { column_name: 'created_at', value: "'2016-03-06 19:53:20.000000'", sql_type: 'datetime' },
        ])
      end
    end

    describe 'skip_timestamps' do
      it 'prevents the timestamps from being included' do
        record = TestRecord::PureTestRecord.new(id: 3, name: 'Michael', age: 123)
        attrs  = PR.Create(record, skip_timestamps: true).attributes_to_insert(current_time: nil)
        expect(attrs).to match_array([
          { column_name: 'name', value: "'Michael'", sql_type: 'varchar' },
          { column_name: 'age',  value: '123',       sql_type: 'integer' },
        ])
      end
    end

    describe 'include_columns' do
      it 'allows you to manually specify columns that would have been excluded' do
        time   = Time.parse('2016-03-06 13:53:20 -0600')
        record = TestRecord::PureTestRecord.new(id: 3, name: 'Michael', age: 123)
        attrs  = PR.Create(record, include_columns: ['id']).attributes_to_insert(current_time: time)
        expect(attrs).to match_array([
          { column_name: 'id',         value: "3",                            sql_type: 'INTEGER' },
          { column_name: 'name',       value: "'Michael'",                    sql_type: 'varchar' },
          { column_name: 'age',        value: '123',                          sql_type: 'integer' },
          { column_name: 'updated_at', value: "'2016-03-06 19:53:20.000000'", sql_type: 'datetime' },
          { column_name: 'created_at', value: "'2016-03-06 19:53:20.000000'", sql_type: 'datetime' },
        ])
      end
    end

    describe 'exclude_columns' do
      it 'allows you to manually specify columns that should not be inserted' do
        time   = Time.parse('2016-03-06 13:53:20 -0600')
        record = TestRecord::PureTestRecord.new(id: 3, name: 'Michael', age: 123)
        attrs  = PR.Create(record, exclude_columns: ['name']).attributes_to_insert(current_time: time)
        expect(attrs).to match_array([
          { column_name: 'age',        value: '123',                          sql_type: 'integer' },
          { column_name: 'updated_at', value: "'2016-03-06 19:53:20.000000'", sql_type: 'datetime' },
          { column_name: 'created_at', value: "'2016-03-06 19:53:20.000000'", sql_type: 'datetime' },
        ])
      end
    end
  end

  describe PR::Actions::Update do
    it 'generates a data structure that represents a database update of a given pure record' do
      record = TestRecord::PureTestRecord.new(id: 2, name: 'Michael', age: 123)
      action = PR.Update(record, ['name'])
      expect(action.table_name).to        eq('test_records')
      expect(action.primary_key).to       eq('id')
      expect(action.primary_key_value).to eq(2)
      expect(action.columns_to_update).to match_array(%w[name updated_at])
    end

    describe 'attributes_to_update' do
      it 'produces an array of fields to update' do
        time   = Time.parse('2016-03-06 13:53:20 -0600')
        record = TestRecord::PureTestRecord.new(id: 2, name: 'Michael', age: 123)
        attrs  = PR.Update(record, ['name']).attributes_to_update(current_time: time)
        expect(attrs).to match_array([
          { column_name: 'name',       value: "'Michael'",                    sql_type: 'varchar' },
          { column_name: 'updated_at', value: "'2016-03-06 19:53:20.000000'", sql_type: 'datetime' },
        ])
      end
    end

    describe 'skip_timestamps' do
      it 'prevents the timestamps from being included' do
        record = TestRecord::PureTestRecord.new(id: 3, name: 'Michael', age: 123)
        attrs  = PR.Update(record, ['name'], skip_timestamps: true).attributes_to_update(current_time: nil)
        expect(attrs).to match_array([
          { column_name: 'name', value: "'Michael'", sql_type: 'varchar' },
        ])
      end
    end
  end

  describe PR::Actions::Delete do
    it 'generates a data structure that represents a database deletion of a given pure record' do
      record = TestRecord::PureTestRecord.new(id: 2, name: 'Michael', age: 123)
      action = PR.Delete(record)
      expect(action.table_name).to        eq('test_records')
      expect(action.primary_key).to       eq('id')
      expect(action.primary_key_value).to eq(2)
    end
  end
end
