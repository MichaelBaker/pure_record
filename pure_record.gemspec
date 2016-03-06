Gem::Specification.new do |s|
  s.name        = 'pure_record'
  s.version     = '0.0.0'
  s.date        = '2016-03-06'
  s.summary     = "A library to transform Active Record models into pure values."
  s.description = "This library helps you guarantee what parts of your code are making database calls and which aren't. It accomplishes this by transforming models that you've pulled from the database into pure values which have no database access."
  s.authors     = ["Michael Baker"]
  s.email       = 'mbaker@trunkclub.com'
  s.files       = [
    'lib/pure_record.rb',
    'lib/pure_record/terse.rb',
    'lib/pure_record/pure_class.rb',
    'lib/pure_record/helpers.rb',
    'lib/pure_record/actions.rb',
  ]
  s.homepage    = "https://github.com/michaelbaker/pure_record"
  s.license     = 'MIT'

  s.add_development_dependency 'rspec',             '~> 3.4'
  s.add_development_dependency 'sqlite3',           '~> 1.3'
  s.add_development_dependency 'database_cleaner',  '~> 1.5'
  s.add_development_dependency 'db-query-matchers', '~> 0.4'

  s.add_runtime_dependency 'rails', '~> 4.0'
end
