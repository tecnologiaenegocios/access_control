ENV["RAILS_ENV"] ||= 'test'
ENV["RAILS_ROOT"] = File.join(File.dirname(__FILE__), 'app')
require File.expand_path(File.join(ENV['RAILS_ROOT'],'config','environment'))

silence_stream($stdout) do
  load File.join(ENV['RAILS_ROOT'],'db','schema.rb')
end

require 'spec/autorun'
require 'spec/rails'
require 'discover'

$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), "..", "lib")))
require 'access_control'

Dir[File.expand_path(File.join(File.dirname(__FILE__), 'support', '**', '*.rb'))].each {|f| require f}

module Spec
  module Example
    module ExampleMethods
      alias_method :execute_without_transaction, :execute
      def execute(*args, &block)
        x = nil
        AccessControl.db.transaction(:rollback => :always) do
          x = execute_without_transaction(*args, &block)
        end
        x
      end
    end
  end
end

Spec::Runner.configure do |config|
  config.use_transactional_fixtures = true
  config.use_instantiated_fixtures  = false
end
