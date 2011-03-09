require 'access_control/exceptions'

module AccessControl

  class ProxyProtectedMethodError < StandardError
  end

  class SecurityProxy

    # Borrowed from
    # http://www.binarylogic.com/2009/08/07/how-to-create-a-proxy-class-in-ruby/
    # See the comments.
    instance_methods.each do |m|
      undef_method m unless m =~ /^__.*__$/
    end

    def initialize target
      if target.class
        raise CannotWrapUnsecurableObject unless target.class.securable?
      end
      @target = target
      @manager = ::AccessControl.get_security_manager
    end

    def security_proxied?
      true
    end

    def remove_security_proxy
      @target
    end

    def method_missing(name, *args, &block)
      method = name == :send ? method = args.first.to_s : name.to_s
      __verify_method_type(method) if name != :send

      if (required = @target.class.permissions_for(method)).any?
        @manager.verify_access!(@target.ac_node, required)
      end

      return_value = @target.__send__(name, *args, &block)
      return SecurityProxy.new(return_value) if __should_wrap?(return_value)

      return_value
    end

    def __should_wrap?(object)
      return false if object.security_proxied?
      return true if object.class.nil? # An association proxy.
      object.class.securable?
    end

    def __verify_method_type method
      if @target.protected_methods.include?(method)
        raise ProxyProtectedMethodError,
              "protected method `#{method}' called for #{@target}"
      end
      if @target.private_methods.include?(method)
        raise NoMethodError, "private method `#{method}' called for #{@target}"
      end
    end

  end

end

Object.class_eval do
  def security_proxied?
    false
  end
  def self.securable?
    false
  end
  def self.permissions_for method_name
    Set.new
  end
end
