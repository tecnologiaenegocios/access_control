require 'rubygems'
require 'fileutils'
require 'pathname'

module AccessControl
  class Migrations
    def initialize(basepath)
      @basepath = basepath
    end

    def update
      source_migrations.each do |migration|
        copy(migration) unless has?(migration)
      end
    end

  private

    attr_reader :basepath

    def source_migrations
      migrations(Dir[basepath + 'migrations' + '*']).sort_by(&:order)
    end

    def migrations(entries)
      entries
        .select { |entry| entry.ends_with?('.rb') }
        .map(&Migration.method(:new))
    end

    def copy(migration)
      FileUtils.copy(migration.path, destination_path(migration))
    end

    def destination_path(migration)
      destination_migrations_path + "#{generate_timestamp}_#{migration.name}.rb"
    end

    def destination_migrations_path
      Rails.root + 'db' + 'migrate'
    end

    def generate_timestamp
      @timestamp = timestamp + 1
    end

    def timestamp
      @timestamp ||= DateTime.now.utc.strftime('%Y%m%d%H%M%S').to_i
    end

    def has?(migration)
      destination_migrations.map(&:name).include?(migration.name)
    end

    def destination_migrations
      @destination_migrations ||=
        migrations(Dir[destination_migrations_path + '*'])
    end

    class Migration
      attr_reader :path, :name, :order

      def initialize(path)
        f = Pathname(path).basename.to_s
        @path = path
        @name = f.sub(/^\d+_/, '').sub(/\.rb$/, '').to_sym
        @order = f[/^\d+/].to_i
      end
    end
  end
end
