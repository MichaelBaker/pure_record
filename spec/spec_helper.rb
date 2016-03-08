require 'sqlite3'
require 'database_cleaner'
require 'db-query-matchers'
require 'pure_record'

ActiveRecord::Base.establish_connection \
  adapter:  "sqlite3",
  database: ":memory:"


ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :test_records do |table|
    table.column :name, :string
    table.column :age,  :integer
    table.timestamps null: true
  end

  create_table :test_associations do |table|
    table.column :test_record_id, :integer
    table.column :city,           :string
  end

  create_table :test_things do |table|
    table.column :test_record_id, :integer
  end

  create_table :test_impure_records do |table|
  end
end

class TestRecord < ActiveRecord::Base
  validates :age, presence: true
  has_many  :test_associations
  has_one   :test_thing

  PureTestRecord = PureRecord.generate_pure_class(self)

  def self.pure_class
    PureTestRecord
  end
end


class TestAssociation < ActiveRecord::Base
  belongs_to :test_record

  PureTestAssociation = PureRecord.generate_pure_class(self)

  def self.pure_class
    PureTestAssociation
  end
end


class TestThing < ActiveRecord::Base
  belongs_to :test_record

  PureTestThing = PureRecord.generate_pure_class(self)

  def self.pure_class
    PureTestThing
  end
end


class TestImpureRecord < ActiveRecord::Base
end
