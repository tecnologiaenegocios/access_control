namespace :db do
  namespace :access_control do
    desc "Access control seeds"
    task :seed => :environment do
      AccessControl::Model::Node.create_global_node!
    end
  end
end

namespace :access_control do
  desc "Generate access control migration"
  task :migration do
    timestamp = DateTime.now.utc.strftime('%Y%m%d%H%M%S')
    if gem = Gem.searcher.find('access_control')
      root_path = gem.full_gem_path
    else
      root_path = AccessControl::ROOT_PATH
    end
    system(
      "cp #{root_path}/create_access_control.rb #{
        Rails.root
      }/db/migrate/#{timestamp}_create_access_control.rb"
    )
  end
end
