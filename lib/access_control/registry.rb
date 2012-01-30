require 'access_control/util'
require 'ostruct'

module AccessControl
  class RegistryFactory

    module Permission
      def self.new(name='')
        permission = OpenStruct.new
        permission.name = name
        permission
      end
    end

    UNION = :|.to_proc
    INTERSECTION = :&.to_proc

    def initialize
      clear_registry
      register_undeclared_permissions
    end

    def clear_registry
      @permissions = Set.new
      @permissions_with_metadata = Hash.new{|h, k| h[k.to_s] = Set.new }
      @permissions_by_metadata = {}
    end

    def register *args
      metadata = args.extract_options!.dup
      Util.make_set_from_args(*args).each do |permission|
        register_permission(permission)
        register_metadata(metadata, permission)
      end
    end

    def all
      @permissions
    end

    def all_with_metadata
      @permissions_with_metadata
    end

    def register_undeclared_permissions(metadata={})
      register([
        'grant_roles',
        'share_own_roles',
        'change_inheritance_blocking'
      ], metadata)
    end

    def query(*criteria)
      return all if criteria.empty?
      criteria.map{|criterion| permissions_matching(criterion)}.inject(&UNION)
    end

  private

    def register_permission(permission)
      all << permission
    end

    def register_metadata(metadata, permission)
      all_with_metadata[permission] << metadata
      metadata.each do |key, value|
        query_permissions(key, value) << permission
      end
    end

    def permissions_matching(criterion)
      return all if criterion.empty?
      criterion.map{|key, value| query_permissions(key, value)}.
        inject(&INTERSECTION)
    end

    def query_permissions(key, value)
      @permissions_by_metadata[[key, value]] ||= Set.new
    end

  end

  Registry = RegistryFactory.new

end
