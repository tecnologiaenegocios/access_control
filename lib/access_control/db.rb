require 'active_record'
require 'sequel'

module AccessControl
  def self.db
    @sequel_db ||= Sequel.connect(sanitized_config)
  end

  def self.sanitized_config
    # Sequel names the sqlite adapter as 'sqlite' whereas ActiveRecord names it
    # as 'sqlite3'.
    config = ActiveRecord::Base.configurations[Rails.env].dup
    if config['adapter'] == 'sqlite3'
      config['adapter'] = 'sqlite'
      config['database'] = Rails.root + config['database']
    end
    config
  end
end
