require 'active_record'
require 'sequel'

module AccessControl
  extend self

    def ac_parents
      db[:ac_parents]
    end

    def ac_nodes
      db[:ac_nodes]
    end

    def ac_effective_assignments
      db[:ac_effective_assignments]
    end

    def bootstrap_sequel!
      @sequel_db = db_connection_with_logging
    end

    def db
      @sequel_db ||= db_connection_with_logging
    end

    def transaction
      ActiveRecord::Base.transaction do
        @sequel_db.transaction do
          yield
        end
      end
    end

  private

    def db_connection_with_logging
      db = Sequel.connect(sanitized_config)
      if @in_memory
        # Load the SQL schema.
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
          # Scope the path to the database to Rails.root if it is relative,
          # since this will be the assumption of ActiveRecord and we want
          # Sequel and ActiveRecord to share the same database.
          unless config['database'].starts_with?('/')
            config['database'] = Rails.root + config['database']
          end
        end
      end
      config
    end
end

AccessControl.bootstrap_sequel!
