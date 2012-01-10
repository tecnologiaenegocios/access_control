$VERBOSE = nil
Rails::Initializer.run do |config|
  config.autoload_paths += %W( #{RAILS_ROOT}/../../lib/ )
end
Dir["../../lib/tasks/*.rake"].each{|ext| load ext}
