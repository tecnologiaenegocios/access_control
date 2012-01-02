require 'active_record'
require 'sequel'

module AccessControl
  def self.ac_parents
    db[:ac_parents]
  end

  class << self

  private

    def db
      @sequel_db ||= db_connection_with_logging
    end

    def db_connection_with_logging
      db = Sequel.connect(sanitized_config)
      if @in_memory
        # Load the schema.
        sql = File.open(File.join(Rails.root, 'db', "#{Rails.env}_structure.sql")).read
        db.run(sql)
      end
      db.loggers << Rails.logger
      db
    end

    def sanitized_config
      # Sequel names the SQLite adapter as 'sqlite' whereas ActiveRecord names
      # it as 'sqlite3'.
      config = ActiveRecord::Base.configurations[Rails.env].dup
      if config['adapter'] == 'sqlite3'
        config['adapter'] = 'sqlite'
        if config['database'] == ':memory:'
          config.delete('database')
          # In a memory database we need to load all the structure from
          # AR::Migrations again, since memory databases are distinct from each
          # other.
          @in_memory = true
        else
          config['database'] = Rails.root + config['database']
        end
      end
      config
    end
  end
end
