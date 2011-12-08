require 'bundler'
Bundler::GemHelper.install_tasks

desc "Load the schema into the test database"
task :load_test_schema do
  require 'active_record'
  require 'yaml'
  base_path = File.dirname(__FILE__)
  rails_root = ENV['RAILS_ROOT'] = File.join(base_path, 'spec', 'app')
  schema_path = File.join(rails_root, 'db', 'schema.rb')
  config_path = File.join(rails_root, 'config', 'database.yml')
  config = YAML.load_file(config_path)['test']
  config['database'] = File.join(rails_root, config['database'])
  ActiveRecord::Base.establish_connection(config)
  load schema_path
end
