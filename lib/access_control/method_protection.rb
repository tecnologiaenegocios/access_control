require 'access_control/registry'

module AccessControl
  module MethodProtection
    def self.included(base)
      base.extend(ClassMethods)
    end

    def self.check(instance, method_name)
      permissions = permissions_for(instance.class, method_name)
      AccessControl.manager.can!(permissions, instance)
    end

    def self.permissions_for(klass, method_name)
      key = [[klass.name, method_name.to_sym]]
      permissions = AccessControl.registry.query(:ac_methods => key)
      if permissions.empty? && klass.superclass
        permissions_for(klass.superclass, method_name)
      else
        permissions
      end
    end

    module ClassMethods
      def protect(method_name, options, &block)
        permission_name = options[:with]
        class_name      = self.name

        prepend(Module.new do
          define_method(method_name) do |*args, &arg_block|
            AccessControl::MethodProtection.check(self, method_name)
            super(*args, &arg_block)
          end
        end)

        Registry.store(permission_name) do |permission|
          permission.ac_methods << [class_name, method_name.to_sym]
          permission.ac_classes << class_name
          yield(permission) if block_given?
        end
      end
    end
  end
end
