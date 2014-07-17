require 'bundler/gem_tasks'

base_path  = File.dirname(__FILE__)
lib_path   = File.join(base_path, "lib")
rails_root = File.join(base_path, 'spec', 'app')

desc "Load the schema into the test database"
task :load_test_schema do
  require 'active_record'
  require 'yaml'
  schema_path = File.join(rails_root, 'db', 'schema.rb')
  config_path = File.join(rails_root, 'config', 'database.yml')
  config = YAML.load_file(config_path)['test']
  config['database'] = File.join(rails_root, config['database'])
  ActiveRecord::Base.establish_connection(config)
  load schema_path
end

desc "Regenerate the migration for 'spec/app'"
task :generate_test_migration do
  require 'fileutils'

  old_migrations = File.join(rails_root, "db", "migrate", "*create_access_control.rb")
  FileUtils.rm(Dir.glob old_migrations)

  template_path = File.join(lib_path, "create_access_control.rb")

  timestamp = Time.now.utc.strftime('%Y%m%d%H%M%S')
  migration_name = "#{timestamp}_create_access_control.rb"
  migration_path = File.join(rails_root, "db", "migrate", migration_name)

  FileUtils.cp(template_path, migration_path)
end
