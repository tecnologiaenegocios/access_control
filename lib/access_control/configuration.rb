module AccessControl

  class Configuration

    attr_reader :default_index_permissions
    attr_reader :default_show_permissions
    attr_reader :default_create_permissions
    attr_reader :default_update_permissions
    attr_reader :default_destroy_permissions
    attr_reader :default_index_permissions_metadata
    attr_reader :default_show_permissions_metadata
    attr_reader :default_create_permissions_metadata
    attr_reader :default_update_permissions_metadata
    attr_reader :default_destroy_permissions_metadata

    attr_reader :default_roles

    # By default, belongs_to associations are seen as ordinary attributes of an
    # instance, that is, they're not restricted by default.  Setting this to
    # true will subject them to normal `find` restriction rules.
    #
    # This can be set per model class or per association, though.
    attr_accessor :restrict_belongs_to_association

    def initialize
      @default_index_permissions = Set.new(['list'])
      @default_show_permissions = Set.new(['view'])
      @default_create_permissions = Set.new(['add'])
      @default_update_permissions = Set.new(['modify'])
      @default_destroy_permissions = Set.new(['delete'])
      @default_index_permissions_metadata = {}
      @default_show_permissions_metadata = {}
      @default_create_permissions_metadata = {}
      @default_update_permissions_metadata = {}
      @default_destroy_permissions_metadata = {}

      @default_roles = Set.new(['owner'])

      @restrict_belongs_to_association = false
    end

    %w(show index create update destroy).each do |name|
      define_method(:"default_#{name}_permissions=") do |*args|
        args = args.compact
        metadata = args.extract_options!
        instance_variable_set(:"@default_#{name}_permissions_metadata",
                              metadata)
        instance_variable_set(:"@default_#{name}_permissions",
                              Util.make_set_from_args(*args))
      end
    end

    def default_roles= *args
      args = args.compact
      @default_roles = Util.make_set_from_args(*args)
    end

    def register_permissions
      Registry.register(default_index_permissions,
                        default_index_permissions_metadata)
      Registry.register(default_show_permissions,
                        default_show_permissions_metadata)
      Registry.register(default_create_permissions,
                        default_create_permissions_metadata)
      Registry.register(default_update_permissions,
                        default_update_permissions_metadata)
      Registry.register(default_destroy_permissions,
                        default_destroy_permissions_metadata)
    end

  end

  def self.configure
    yield @config ||= Configuration.new
  end

  def self.config
    @config ||= Configuration.new
  end

end
