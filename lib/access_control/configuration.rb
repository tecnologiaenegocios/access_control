module AccessControl

  class Configuration

    attr_reader :default_query_permissions
    attr_reader :default_view_permissions
    attr_reader :default_create_permissions
    attr_reader :default_update_permissions
    attr_reader :default_destroy_permissions

    attr_reader :default_roles_on_create

    attr_accessor :tree_creation

    def initialize
      @default_query_permissions = Set.new(['query'])
      @default_view_permissions = Set.new(['view'])
      @default_create_permissions = Set.new(['add'])
      @default_update_permissions = Set.new(['modify'])
      @default_destroy_permissions = Set.new(['delete'])

      @default_roles_on_create = Set.new(['owner'])

      @tree_creation = true
    end

    %w(view query create update destroy).each do |name|
      define_method(:"default_#{name}_permissions=") do |*args|
        instance_variable_set(:"@default_#{name}_permissions",
                              Util.make_set_from_args(*args))
      end
    end

    def default_roles_on_create= *args
      if args.compact.empty?
        @default_roles_on_create = nil
      else
        @default_roles_on_create = Util.make_set_from_args(*args)
      end
    end

    def register_permissions
      PermissionRegistry.register(default_query_permissions)
      PermissionRegistry.register(default_view_permissions)
      PermissionRegistry.register(default_create_permissions)
      PermissionRegistry.register(default_update_permissions)
      PermissionRegistry.register(default_destroy_permissions)
    end

  end

  def self.configure
    yield @config ||= Configuration.new
  end

  def self.config
    @config ||= Configuration.new
  end

end
