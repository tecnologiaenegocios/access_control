module AccessControl

  class Configuration

    include AccessControl::Util

    attr_reader :default_query_permissions
    attr_reader :default_view_permissions
    attr_reader :default_update_permissions
    attr_reader :default_create_permissions
    attr_accessor :tree_creation

    def initialize
      @default_query_permissions = Set.new(['query'])
      @default_view_permissions = Set.new(['view'])
      @default_create_permissions = Set.new(['add'])
      @default_update_permissions = Set.new(['modify'])
      @tree_creation = true
    end

    { :view => 'view', :query => 'query',
      :create => 'add', :update => 'modify'}.each do |name, permission|
      define_method(:"default_#{name}_permissions=") do |*args|
        instance_variable_set(:"@default_#{name}_permissions",
                              make_set_from_args(*args))
      end
    end

  end

  def self.configure
    yield @config ||= Configuration.new
  end

  def self.config
    @config ||= Configuration.new
  end

end
