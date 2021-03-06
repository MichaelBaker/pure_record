# Pure Record

## The Problem

Active Record makes it incredibly easy to perform database queries. It is so easy, that it's common to litter your code with them. Anytime you need something from the database, you just drop in another query.

It's also easy to accidentally query the database when you didn't intend to because Active Record helpfully loads a record's associations when you go to, say, map over them.

These behaviors can lead to code that has unpredictable performance (due to lazy loading) and is difficult to test (due to being littered with side effects).

## The Solution

This gem provides tools to help you restructure your code as follows.

1. Gather all of your data from the database.
1. Transform that data as dictated by your use case.
1. Write the result back to the database.

With this pattern, you perform side effects at the beginning and the end, but the middle doesn't do anything with the database.

Explicitly delimiting what parts of your code will touch the database makes it easier to tell where performance problems might lurk and leads you naturally toward a functional style, which I find easier to understand and maintain.

## Examples

First, require pure_record.

```ruby
require 'pure_record'
```

If you prefer a shorter namespace, `require 'pure_record/terse'` will alias `PureRecord` to the shorter `PR`.

Here is our example schema.

```ruby
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
end
```

You start by generating pure versions of your models by passing the model's class to `PureRecord.generate_pure_class`. This will return a pure version of the Active Record class. You must also define the `pure_class` method on your Active Record class. This is how the `purify` method knows which class to use when converting a given Active Record model into a pure model.

```ruby
class TestRecord < ActiveRecord::Base
  validates :age, presence: true
  has_many  :test_associations

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
```

Now that the models have pure versions, they can be converted back and forth using `purify` and `impurify`.

```ruby
records        = TestRecord.where(name: 'Alexander').all.to_a
pure_records   = PureRecord.purify(records)

pure_records.each do |record|
  record.age ||= 0
  record.age += 1
end

impure_records = PureRecord.impurify(pure_records)
impure_records.each(&:save)
```

`purify` requires that all of the data you want to work with be loaded into memory already. This is why we had to call `to_a` on the relation in the previous example.

This same requirement holds true for associations. If you try to use an association that hasn't been loaded, you will receive an error.

```ruby
record      = TestRecord.find(4)
pure_record = PureRecord.purify(record)
pure_record.test_assoications.map(&:city) # => PureRecord::UnloadedAssociationError: 
  # You tried to access association test_associations on TestRecord::PureTestRecord, but
  # that association wasn't loaded when the pure record was constructed. You might want
  # to use the '.includes(:test_associations)' option when querying for TestRecord.
```

As the error message states, you need to `includes` any associations you intend to use in your pure code.

```ruby
record      = TestRecord.includes(:test_associations).find(4)
pure_record = PureRecord.purify(record)
pure_record.test_associations.map(&:city) # => ["Chicago", "L.A.", "New York"]
```
