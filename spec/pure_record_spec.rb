require 'spec_helper'
require 'pure_record'

RSpec.describe PureRecord do
  before(:all)  { DatabaseCleaner.strategy = :transaction }
  before(:each) { DatabaseCleaner.start }
  after(:each)  { DatabaseCleaner.clean }


  describe 'generate_pure_class' do
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
        PureRecord.generate_pure_class(String)
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

    it 'doesn\'t modify the hash of arguments' do
      opts = {name: 'Jimmy Johnson', loaded_associations: true}
      TestRecord::PureTestRecord.new(opts)
      expect(opts).to eq name: 'Jimmy Johnson', loaded_associations: true
    end
  end

  describe '.purify' do
    it 'returns a pure record with the same values as the receiving Active Record model' do
      record      = TestRecord.new(name: 'Michael', age: 123)
      pure_record = PureRecord.purify record
      expect(pure_record.name).to eq('Michael')
      expect(pure_record.age).to  eq(123)
    end

    it 'records that the active record model has been persisted' do
      record      = TestRecord.create!(name: 'Michael', age: 123)
      pure_record = PureRecord.purify record
      expect(pure_record.already_persisted?).to be true
    end

    it 'records that the active record model has not been persisted yet' do
      record      = TestRecord.new(name: 'Michael', age: 123)
      pure_record = PureRecord.purify record
      expect(pure_record.already_persisted?).to be false
    end

    it "does not purify associations which haven't already been loaded" do
      record = TestRecord.create!(name: 'Michael', age: 123)
      TestAssociation.create!(test_record: record, city: 'Chicago')
      pure_record = PureRecord.purify record
      expect do
        pure_record.test_associations
      end.to raise_error(PureRecord::PureClass::UnloadedAssociationError)
    end

    it 'allows you to create pure array of all associations',t:true do
      TestRecord.create!(name: 'Michael', age: 123) do |record|
        record.test_associations.build city: 'Chicago'
        record.test_associations.build city: 'Denver'
      end

      record = TestRecord.includes(:test_associations).first
      pure_record = PureRecord.purify record

      assoc1, assoc2, *rest = pure_record.test_associations
      expect(rest).to eq []
      expect(assoc1.city).to eq 'Chicago'
      expect(assoc2.city).to eq 'Denver'
      expect(assoc1.test_record_id).to eq record.id
      expect(assoc2.test_record_id).to eq record.id

      expect(assoc1.test_record).to equal pure_record
      expect(assoc2.test_record).to equal pure_record
    end

    it "raises an error if the record hasn't had a purified class generated for it" do
      expect do
        PureRecord.purify(TestImpureRecord.new)
      end.to raise_error(ArgumentError, /pure class/)
    end

    it "doesn't make any database queries" do
      record = TestRecord.create!(name: 'Michael', age: 123)
      TestAssociation.create!(test_record: record, city: 'Chicago')
      TestThing.create!(test_record: record)
      impure_records = TestRecord.includes(:test_associations, :test_thing).all.to_a

      expect do
        PureRecord.purify(impure_records)
      end.to_not make_database_queries
    end

    it 'raises an error if you try to use it with a relation (as opposed to an array)' do
      expect do
        PureRecord.purify(TestRecord.where(name: 'Michael'))
      end.to raise_error(ArgumentError, /array of instances/)
    end
  end

  describe '.impurify' do
    it 'updates an impure record correctly after changing an attribute' do
      record           = TestRecord.create!(name: 'Michael', age: 123)
      pure_record      = PureRecord.purify record
      pure_record.name = 'Hello'
      expect(TestRecord.count).to eq(1)
      PureRecord.impurify(pure_record).save!
      expect(TestRecord.count).to      eq(1)
      expect(TestRecord.first.age).to  eq(123)
      expect(TestRecord.first.name).to eq('Hello')
    end

    it 'creates an impure record correctly after setting attributes' do
      record           = TestRecord.new(name: 'Michael', age: 123)
      pure_record      = PureRecord.purify record
      pure_record.name = 'Hello'
      expect(TestRecord.count).to eq(0)
      PureRecord.impurify(pure_record).save!
      expect(TestRecord.count).to      eq(1)
      expect(TestRecord.first.age).to  eq(123)
      expect(TestRecord.first.name).to eq('Hello')
    end

    it 'it impurifies associations' do
      record = TestRecord.create!(name: 'Michael', age: 123)
      TestAssociation.create!(test_record: record, city: 'Chicago')
      TestThing.create!(test_record: record)
      pure_record   = PureRecord.purify TestRecord.includes(:test_associations, :test_thing).first
      impure_record = PureRecord.impurify(pure_record)

      expect(impure_record.test_associations.count).to             eq(1)
      expect(impure_record.test_associations.first.test_record).to equal(impure_record)
    end

    it 'markes associations as pre-loaded when impurifying them' do
      record = TestRecord.create!(name: 'Michael', age: 123)
      TestAssociation.create!(test_record: record, city: 'Chicago')
      pure_record   = PureRecord.purify(TestRecord.includes(:test_associations, :test_thing).first)
      impure_record = PureRecord.impurify(pure_record)

      expect do
        impure_record.test_associations.map(&:city)
        impure_record.test_thing
      end.to_not make_database_queries
    end

    it "doesn't make any database queries" do
      record = TestRecord.create!(name: 'Michael', age: 123)
      TestAssociation.create!(test_record: record, city: 'Chicago')
      TestThing.create!(test_record: record)
      pure_record = PureRecord.purify(TestRecord.includes(:test_associations, :test_thing).first)

      expect do
        PureRecord.impurify(pure_record)
      end.to_not make_database_queries
    end

    it 'raises an error if you try to use it with something bogus' do
      record = TestRecord.create!(name: 'Michael', age: 123)
      expect do
        PureRecord.impurify(record)
      end.to raise_error(ArgumentError, /array of instances/)
    end
  end

  describe 'valid?' do
    it "runs the model's validations" do
      pure_record = TestRecord::PureTestRecord.new(name: 'Michael')
      expect(PureRecord.validate(pure_record)).to be false
      pure_record.age = 30
      expect(PureRecord.validate(pure_record)).to be true
    end
  end

  it "tells you when you're trying to do something that would be valid, if this weren't a pure record" do
    record      = TestRecord.new(name: 'Michael', age: 123)
    pure_record = PureRecord.purify record
    expect do
      pure_record.save
    end.to raise_error(NoMethodError, /is not a pure method/)
  end
end
