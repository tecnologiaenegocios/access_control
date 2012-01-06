require File.join(File.dirname(__FILE__), 'boot')
Rails::Initializer.run do |config|
  config.autoload_paths += %W( #{RAILS_ROOT}/../../lib/ )
  config.time_zone = 'UTC'
end
