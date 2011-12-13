ENV["RAILS_ENV"] ||= 'test'
ENV["RAILS_ROOT"] = File.join(File.dirname(__FILE__), 'app')
require File.expand_path(File.join(ENV['RAILS_ROOT'],'config','environment'))
require 'spec/autorun'
require 'spec/rails'
require 'discover'

Dir[File.expand_path(File.join(File.dirname(__FILE__), 'support', '**', '*.rb'))].each {|f| require f}

Spec::Runner.configure do |config|
  config.use_transactional_fixtures = true
  config.use_instantiated_fixtures  = false
end
