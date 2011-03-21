namespace :db do
  namespace :access_control do
    desc "Access control seeds"
    task :seed => :environment do
      if !AccessControl::Node.global
        AccessControl::Node.create_global_node!
      end
      if !AccessControl::Principal.anonymous
        AccessControl::Principal.create_anonymous_principal!
      end
    end
  end
end

namespace :access_control do
  desc "Generate access control migration"
  task :migration do
    require 'ftools'
    ts = DateTime.now.utc.strftime('%Y%m%d%H%M%S')
    if gem = Gem.searcher.find('access_control')
      root_path = File.join(gem.full_gem_path, 'lib')
    else
      root_path = AccessControl::LIB_PATH
    end
    source_path = File.join(root_path, 'create_access_control.rb')
    destination_path = File.join(
      Rails.root, 'db', 'migrate', "#{ts}_create_access_control.rb"
    )
    File.syscopy(source_path, destination_path)
  end
end
