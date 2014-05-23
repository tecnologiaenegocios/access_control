# From http://djellemah.com/blog/2013/02/27/rails-23-with-ruby-20/
# monkey patch for 2.0. Will ignore vendor gems.
if Gem::RubyGemsVersion >= "2.0.0"
  module Gem
    def self.source_index
      sources
    end

    def self.cache
      sources
    end

    remove_const 'SourceIndex' if defined?(SourceIndex)
    const_set('SourceIndex', Specification)

    # class SourceList
    #   # If you want vendor gems, this is where to start writing code.
    #   def search( *args ); []; end
    #   def each( &block ); end
    #   include Enumerable
    # end
  end
end

require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  config.autoload_paths += %W( #{RAILS_ROOT}/../../lib/ )
  config.time_zone = 'UTC'
end

require 'access_control/configuration'

AccessControl.configure do |config|
  ar_config = ActiveRecord::Base.configurations[Rails.env]

  in_memory = false
  sequel_config = ar_config.dup.tap do |db_config|
    if db_config['adapter'] == 'sqlite3'
      db_config['adapter'] = 'sqlite'
      if db_config['database'] == ':memory:'
        db_config.delete('database')
        # In a memory database we need to load all the structure from
        # AR::Migrations again, since memory databases are distinct from each
        # other.
        in_memory = true
      else
        # Scope the path to the database to Rails.root if it is relative,
        # since this will be the assumption of ActiveRecord and we want
        # Sequel and ActiveRecord to share the same database.
        unless db_config['database'].starts_with?('/')
          db_config['database'] = Rails.root + db_config['database']
        end
      end
    elsif db_config['adapter'].starts_with?("jdbc")
      break "jdbc:mysql://localhost/#{db_config['database']}?user=#{db_config['username']}"
    end
  end

  config.db = Sequel.connect(sequel_config).tap do |db|
    if in_memory
      # Load the SQL schema.
      sql = File.open(File.join(Rails.root, 'db', "#{Rails.env}_structure.sql")).read
      db.run(sql)
    end

    db.loggers << Rails.logger
  end
end
