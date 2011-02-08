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
      raise CannotWrapUnsecurableObject unless target.securable?
      @target = target
      @manager = ::AccessControl.get_security_manager
    end

    def security_proxied?
      true
    end

    def securable?
      false
    end

    def remove_security_proxy
      @target
    end

    def method_missing(name, *args, &block)
      method = name == :send ? method = args.first.to_s : name.to_s
      __verify_method_type(method)

      if (required = @target.class.permissions_for(method)).any?
        @manager.verify_access!(@target.ac_nodes, required)
      end

      return_value = @target.__send__(name, *args, &block)
      return SecurityProxy.new(return_value) if return_value.securable?

      return_value
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
  def securable?
    false
  end
  def self.permissions_for method_name
    Set.new
  end
end
