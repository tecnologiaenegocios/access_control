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
