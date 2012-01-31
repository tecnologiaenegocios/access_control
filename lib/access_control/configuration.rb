require 'access_control/util'
require 'access_control/registry_factory'

module AccessControl

  class Configuration

    attr_reader :default_roles

    def initialize
      @default_permissions = {
        :index   => Set['list'],
        :show    => Set['view'],
        :create  => Set['add'],
        :update  => Set['modify'],
        :destroy => Set['delete']
      }

      @default_roles = Set['owner']

      @restrict_belongs_to_association = false
    end

    %w(show index create update destroy).map(&:to_sym).each do |name|
      define_method(:"default_#{name}_permissions") do
        @default_permissions[name]
      end

      define_method(:"default_#{name}_permissions=") do |permissions|
        permissions_set = Set.new [*permissions].compact
        @default_permissions[name] = permissions_set
      end
    end

    def default_roles= *args
      args = args.compact
      @default_roles = Util.make_set_from_args(*args)
    end

    def register_permissions
      all_default_permissions = @default_permissions.values.inject(&:merge)
      all_default_permissions.each do |permission|
        Registry.store(permission)
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
