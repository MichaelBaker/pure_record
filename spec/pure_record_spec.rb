require 'pure_record'
require 'active_record'
require 'sqlite3'
require 'database_cleaner'

# TODO
#
# Features
# --------
# Associations
# Lenses for persistent updates
# purity of mutation

ActiveRecord::Base.establish_connection \
  adapter:  "sqlite3",
  database: ":memory:"


ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :test_records do |table|
    table.column :name, :string
    table.column :age,  :integer
  end

  create_table :test_associations do |table|
    table.column :test_record_id, :integer
  end
end

class TestRecord < ActiveRecord::Base
  validates :age, presence: true
  has_many  :test_associations

  PureRecord.create_pure_class(self) do
  end
end

class TestAssociation < ActiveRecord::Base
  belongs_to :test_record
end

class TestRecord < ActiveRecord::Base
  validates :age, presence: true
end

describe PureRecord do
  before(:all)  { DatabaseCleaner.strategy = :transaction }
  before(:each) { DatabaseCleaner.start }
  after(:each)  { DatabaseCleaner.clean }


  describe 'create_pure_class' do
    it 'creates a new class with only plain setters and getters from the Active Record class' do
      expect(TestRecord.const_defined?('PureTestRecord')).to be true
      TestRecord.columns.map(&:name).each do |column|
        pure_record = TestRecord::PureTestRecord.new
        pure_record.send(column)
        pure_record.send("#{column}=", 1)
      end
    end

    it "raises an error if you try to create a pure class for something that isn't a subclass of ActiveRecord::Base" do
      expect do
        PureRecord.create_pure_class(String)
      end.to raise_error(ArgumentError, /not a subclass of ActiveRecord::Base/)
    end
  end

  describe 'initialize' do
    it "produces an error when you try to pass attributes which aren't columns of the Active Record model" do
      expect do
        TestRecord::PureTestRecord.new(hello: 'there')
      end.to raise_error(ArgumentError, /invalid attributes/)
    end

    it 'allows you to pass invalid keys with the ignore_extra_attrs option' do
      TestRecord::PureTestRecord.new(hello: 'there', options: { ignore_extra_attrs: true })
    end
  end

  describe 'pure' do
    it 'returns a pure record with the same values as the receiving Active Record model' do
      record      = TestRecord.new(name: 'Michael', age: 123)
      pure_record = record.pure
      expect(pure_record.name).to eq('Michael')
      expect(pure_record.age).to  eq(123)
    end

    it 'records that the active record model has been persisted' do
      record      = TestRecord.create!(name: 'Michael', age: 123)
      pure_record = record.pure
      expect(pure_record.already_persisted).to be true
    end

    it 'records that the active record model has not been persisted yet' do
      record      = TestRecord.new(name: 'Michael', age: 123)
      pure_record = record.pure
      expect(pure_record.already_persisted).to be false
    end
  end

  describe 'valid?' do
    it "runs the model's validations" do
      pure_record = TestRecord::PureTestRecord.new(name: 'Michael')
      expect(pure_record.valid?).to be false
      pure_record.age = 30
      expect(pure_record.valid?).to be true
    end
  end

  it "tells you when you're trying to do something that would be valid, if this weren't a pure record" do
    record      = TestRecord.new(name: 'Michael', age: 123)
    pure_record = record.pure
    expect do
      pure_record.save
    end.to raise_error(NoMethodError, /is not a pure method/)
  end

  it 'updates an impure record correctly after changing an attribute' do
    record           = TestRecord.create!(name: 'Michael', age: 123)
    pure_record      = record.pure
    pure_record.name = 'Hello'
    expect(TestRecord.count).to eq(1)
    pure_record.impure.save!
    expect(TestRecord.count).to      eq(1)
    expect(TestRecord.first.age).to  eq(123)
    expect(TestRecord.first.name).to eq('Hello')
  end

  it 'creates an impure record correctly after setting attributes' do
    record           = TestRecord.new(name: 'Michael', age: 123)
    pure_record      = record.pure
    pure_record.name = 'Hello'
    expect(TestRecord.count).to eq(0)
    pure_record.impure.save!
    expect(TestRecord.count).to      eq(1)
    expect(TestRecord.first.age).to  eq(123)
    expect(TestRecord.first.name).to eq('Hello')
  end
end
