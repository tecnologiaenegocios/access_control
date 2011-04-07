require 'access_control/util'

module AccessControl
  module PermissionRegistry

    class << self

      def clear_registry
        @permissions = Set.new
      end

      def register *args
        @permissions = (@permissions || Set.new) |
          Util.make_set_from_args(*args)
      end

      def registered
        load_all_controllers
        load_all_models
        register_undeclared_permissions
        @permissions || Set.new
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

      def load_top_level_constant filename
        # We can't simply load or require the file by its filename because of
        # the handling of cached classes in Rails, so we deduce their class
        # name from the filename and get the constant (a.k.a. the top level
        # class).  If the class wasn't loaded yet, ActiveSupport::Dependencies
        # will get it from the file anyway, taking into consideration the
        # cache_class config option.
        File.basename(filename, '.rb').camelize.constantize
      end

      def register_undeclared_permissions
        register([
          'grant_roles',
          'share_own_roles',
          'change_inheritance_blocking'
        ])
      end

    end

  end
end
