system({ 'RAILS_ENV' => 'test' }, 'bundle', 'exec', 'rake', 'db:create', chdir: 'spec/app')
system({ 'RAILS_ENV' => 'test' }, 'bundle', 'exec', 'rake', 'db:migrate', chdir: 'spec/app')

ENV["RAILS_ENV"] ||= 'test'
ENV["RAILS_ROOT"] = File.join(File.dirname(__FILE__), 'app')
require File.expand_path(File.join(ENV['RAILS_ROOT'],'config','environment'))

def require_files_under_dir(dir)
  path = File.expand_path(File.join(ENV['RAILS_ROOT'], '..', dir, '**', '*.rb'))
  Dir[path].each {|f| require f}
end

require_files_under_dir File.join("integration", "shared_examples")

require 'spec/autorun'
require 'spec/rails'
require 'discover'
require 'database_cleaner'

ActiveRecord::Base.connection.execute("SET FOREIGN_KEY_CHECKS=0")
AccessControl.db.run("SET FOREIGN_KEY_CHECKS=0")

$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), "..", "lib")))
require 'access_control'

Dir[File.expand_path(File.join(File.dirname(__FILE__), 'support', '**', '*.rb'))].each {|f| require f}

DatabaseCleaner.strategy = :deletion
at_exit do
  system({ 'RAILS_ENV' => 'test' }, 'bundle', 'exec', 'rake', 'db:drop', chdir: 'spec/app')
end

Spec::Runner.configure do |config|
  config.use_transactional_fixtures = false
  config.use_instantiated_fixtures  = false

  config.before(:each) do
    if defined?(Registry)
      Registry.clear
    end
  end

  config.after(:each) do
    if defined?(Registry)
      Registry.clear
    end
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
