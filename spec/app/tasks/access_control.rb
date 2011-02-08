$VERBOSE = nil
Rails::Initializer.run do |config|
  config.load_paths += %W( #{RAILS_ROOT}/../../lib/ )
end
Dir["../../lib/tasks/*.rake"].each{|ext| load ext}
