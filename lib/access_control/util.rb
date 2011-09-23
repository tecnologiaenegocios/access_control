module AccessControl

  module Util

    class << self

      def log_missing_permissions requirements, current, roles, trace
        AccessControl::Logger.log_missing_permissions(
          make_set_from_args(requirements),
          make_set_from_args(current),
          make_set_from_args(roles),
          trace
        )
      end

      def log_unregistered_permission permission
        AccessControl::Logger.log_unregistered_permission(permission)
      end

      def make_set_from_args *args
        if args.size == 1 && args.first.is_a?(Enumerable)
          return Set.new(args.first)
        end
        Set.new(args)
      end

      def prettify_sql(sql)
        sql.gsub(/^\s*/, '').gsub(/\n\s*/, '')
      end

      # Platform checks
      # ---------------

      # Test if Class#new calls Class#allocate when Class#allocate is
      # overridden.
      #
      # In some Ruby implementations, like Rubinius, .new calls .allocate even
      # if it is overridden, unlike in MRI where .new calls only the C
      # implementation of #allocate (effectively skipping the overriding
      # implementation).  So in the platforms where .new calls the overridden
      # .allocate we don't do our dark wizardry for instance creation twice,
      # since it is enough to do it by overriding .allocate.  On the other
      # hand, if .new only calls the low-level implementation directly, we need
      # to do our magic in .allocate and in .new as well.
      #
      # But why the hell one wants to override .allocate?  Isn't .new just as
      # good?  Unfortunatelly no, because ActiveRecord calls .allocate to
      # create instances from .find, and even then we want our funny tricks
      # working.
      def new_calls_allocate?
        return @new_calls_allocate unless @new_calls_allocate.nil?
        @new_calls_allocate = false
        klass = Class.new do
          def self.allocate
            AccessControl::Util.new_calls_allocate!
            super
          end
        end
        klass.new
        @new_calls_allocate
      end

      def new_calls_allocate!
        @new_calls_allocate = true
      end

    end

  end

  module Logger

    class << self

      def format_trace trace
        trace = clean_trace(trace)
        if ActiveRecord::Base.colorize_logging
          trace.map!{|t| "\e[31;2m#{t}\e[0m"}
        end
        trace.map{|t| "    #{t}"}.join("\n")
      end

      def clean_trace trace
        Rails.respond_to?(:backtrace_cleaner) ?
          Rails.backtrace_cleaner.clean(trace) :
          trace
      end

      def format_permissions permissions
        permissions.to_a.map(&:inspect).to_sentence(:locale => 'en')
      end

      def format_current_roles roles
        roles.to_a.map(&:name).to_sentence(:locale => 'en')
      end

      def format_unauthorized_message missing_permissions, current_roles
        principals = AccessControl.manager.principal_ids
        msg = "Access denied for principal(s) #{
          principals.to_sentence(:locale => 'en')
        } (roles: #{current_roles}): missing #{missing_permissions}"
        if ActiveRecord::Base.colorize_logging
          return "  \e[31;1m#{msg}\e[0m\n"
        end
        "  #{msg}\n"
      end

      def format_unregistered_permission_message permission
        base = "Permission \"#{permission}\" is not registered"
        if ActiveRecord::Base.colorize_logging
          return "\e[31;1m#{base}\e[0m"
        end
        base
      end

      def log_missing_permissions requirements, current, roles, trace
        missing_permissions = format_permissions(requirements - current)
        current_roles = format_current_roles(roles)
        Rails.logger.info(
          format_unauthorized_message(missing_permissions, current_roles) +
          format_trace(trace)
        )
      end

      def log_unregistered_permission permission
        Rails.logger.info(format_unregistered_permission_message(permission))
      end

    end

  end
end
