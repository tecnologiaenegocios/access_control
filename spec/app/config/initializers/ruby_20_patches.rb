# On ruby 2.0.0, respond_to? doesn't return true for protected methods anymore
# https://github.com/rails/rails/issues/11026#issuecomment-26921562
if defined?(Rails)
  is_rails_before_31 = Rails::VERSION::MAJOR < 3 || (Rails::VERSION::MAJOR == 3 && Rails::VERSION::MINOR < 1)
else
  is_rails_before_31 = true
end

if RUBY_VERSION >= "2.0.0" && is_rails_before_31
  # Force-load activerecord before, otherwise dependencies gets angry...
  require 'active_record/base'

  module ActiveRecord
    module Associations
      class AssociationProxy
        def send(method, *args)
          if proxy_respond_to?(method, true)
            super
          else
            load_target
            @target.send(method, *args)
          end
        end
      end
    end
  end

  # The filter_parameter_logging method, used to filter request parameters
  # (such as passwords) from the log, defines a protected method called
  # filter_parameter when called. Its existence is later tested using
  # respond_to?, without the include_private parameter. Due to the respond_to?
  # behavior change, the method existence is never detected, and parameter
  # filtering stops working.
  require 'action_controller'

  module ParameterFilterPatch
    def respond_to?(method, include_private = false)
      if method.to_s == 'filter_parameters'
        include_private = true
      end

      super(method, include_private)
    end
  end

  module ActionController
    class Base
      prepend ParameterFilterPatch
    end
  end

  # Just like the above patch for parameter filtering, translations are loaded
  # and merged automatically in the load_file method of I18n::Backend::Base.
  # This method takes the filename extension to decide to which method to
  # delegate in order to load the translations.  For now we are providing a fix
  # for the .rb and .yml translation formats, which are defined in the same
  # module and happen to be protected methods.
  require 'i18n'

  module LoadFilePatch
    def respond_to?(method, include_private = false)
      if %w(load_rb load_yml).include?(method.to_s)
        include_private = true
      end

      super(method, include_private)
    end
  end

  module I18n
    module Backend
      module Base
        prepend LoadFilePatch
      end
    end
  end
end
