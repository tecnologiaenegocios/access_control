require 'pathname'

namespace :db do
  namespace :access_control do
    dirname = __dir__

    desc "Add/update access control migrations"
    task :migrations do
      require 'access_control/migrations'
      AccessControl::Migrations.new(Pathname(dirname) + '..').update
    end
  end
end
