require 'access_control/db'
require 'access_control/util'
require 'access_control/registry'

module AccessControl

  class Configuration

    attr_reader :default_roles

    def initialize
      @default_permissions = {}
      @default_roles = Set['owner']
      @restrict_belongs_to_association = false
    end

    %w(show list create update destroy).map(&:to_sym).each do |name|
      define_method(:"permissions_required_to_#{name}") do
        registry.fetch_all(@default_permissions[name] || []).to_set
      end

      define_method(:"#{name}_requires") do |permissions, &block|
        permissions_set = Set.new [*permissions].compact
        @default_permissions[name] = permissions_set
        permissions_set.each do |permission_name|
          registry.store(permission_name, &block)
        end
      end
    end

    def default_roles= *args
      args = args.compact
      @default_roles = Util.make_set_from_args(*args)
    end

    def extend_permissions(&block)
      RegistryFactory::Permission.class_exec(&block)
    end

    def db= db
      AccessControl.db = db
    end

    def db
      AccessControl.db
    end

    def registry
      # At the point the application is configured, the API method
      # AccessControl.registry may not be present.  The configuration object
      # provide convenient access to the registry object to configurators, by
      # exposing the registry object directly by its constant.
      AccessControl::Registry
    end
  end

  def self.configure
    yield config
  end

  def self.config
    @config ||= Configuration.new
  end

end
