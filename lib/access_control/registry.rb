require 'access_control/util'

module AccessControl
  module Registry

    class << self

      def clear_registry
        @permissions = nil
        @permissions_with_options = nil
      end

      def register *args
        options = args.extract_options!
        Util.make_set_from_args(*args).each do |p|
          permissions << p
          permissions_with_options[p] << options.dup
        end
      end

      def all
        permissions
      end

      def all_with_options
        permissions_with_options
      end

      def register_undeclared_permissions
        register([
          'grant_roles',
          'share_own_roles',
          'change_inheritance_blocking'
        ])
      end

      def load_all_controllers
        Dir[Rails.root + 'app/controllers/**/*.rb'].each do |path|
          load_top_level_constant(path)
        end
      end

      def load_all_models
        Dir[Rails.root + 'app/models/**/*.rb'].each do |path|
          load_top_level_constant(path)
        end
      end

      def load_all_permissions_from_config
        AccessControl.config.register_permissions
      end

    private

      def load_top_level_constant filename
        # We can't simply load or require the file by its filename because of
        # the handling of cached classes in Rails, so we deduce their class
        # name from the filename and get the constant (a.k.a. the top level
        # class).  If the class wasn't loaded yet, ActiveSupport::Dependencies
        # will get it from the source file based on the its name anyway, taking
        # into consideration the cache_class config option.
        filename.
          gsub(Rails.root + 'app/models/', '').
          gsub(Rails.root + 'app/controllers/', '').
          gsub(/\.rb$/, '').
          camelize.
          constantize
      end

      def permissions
        @permissions ||= Set.new
      end

      def permissions_with_options
        @permissions_with_options ||= Hash.new{|h, k| h[k.to_s] = Set.new }
      end

    end

  end
end
