require 'pathname'
require 'fileutils'

namespace :db do
  namespace :access_control do

    migration_paths = Pathname(__dir__).join("../migrations").children
      .select { |path| path.readable? && path.extname == ".rb" }

    migrations = migration_paths.map { |migration_path|
      migration_name = migration_path.basename.to_s.sub(/\.rb$/, '')
      [migration_name, migration_path]
    }

    namespace :migrations do
      migrations.each do |migration_name, migration_path|
        desc "Generate access control migration #{migration_name}"
        task migration_name do
          ts = DateTime.now.utc.strftime('%Y%m%d%H%M%S').to_i
          destination_dir = Pathname(Rails.root) + 'db/migrate'

          existing_timestamps = destination_dir.children.map { |child|
            child.basename.to_s[/^[0-9]+/].to_i
          }

          while existing_timestamps.include?(ts)
            ts += 1
          end

          destination_path = destination_dir + "#{ts}_#{migration_name}.rb"
          FileUtils.copy(migration_path, destination_path)
        end
      end
    end

    desc "Generate all access control migrations"
    task :migrations => migrations.map { |name, _| "migrations:#{name}" }
  end
end
