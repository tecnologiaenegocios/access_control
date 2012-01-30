require 'access_control/util'

module AccessControl
  class RegistryFactory

    UNION        = :merge.to_proc
    INTERSECTION = Proc.new do |s1, s2|
      s1.keep_if { |obj| s2.member?(obj) }
    end

    def initialize
      register_undeclared_permissions
    end

    def clear_registry
      @registered_permissions = nil
    end

    def register(*args)
      metadata = args.extract_options!

      permissions = args.each_with_object(Array.new) do |argument, array|
        case argument
        when Array
          array.concat(argument)
        when Set
          array.concat(argument.to_a)
        else
          array << argument
        end
      end

      permissions.each do |permission|
        registered_permissions[permission] << metadata
      end
    end

    def all
      Set.new(registered_permissions.keys)
    end

    def all_with_metadata
      registered_permissions.dup
    end

    def register_undeclared_permissions(metadata={})
      permissions = %w[grant_roles share_own_roles change_inheritance_blocking]
      register(permissions, metadata)
    end

    def query(*criteria)
      return all if criteria.all?(&:empty?)

      matching = filtered_by_query(criteria) do |permission, _|
        permission
      end
      Set.new(matching)
    end

  private

    def registered_permissions
      @registered_permissions ||= Hash.new do |hash, permission_name|
        hash[permission_name] = Set.new
      end
    end

    def filtered_by_query(criteria, &block)
      criteria.flat_map do |criterion|
        permissions = permissions_matching(criterion)
        if block_given?
          permissions.map(&block)
        else
          permissions
        end
      end
    end

    def permissions_matching(criterion)
      return all if criterion.empty?

      criterion.each_with_object(all_with_metadata) do |(key, value), result|
        result.keep_if do |_, metadata_set|
          metadata_set.any? { |metadata| metadata[key] == value }
        end
      end
    end
  end

  Registry = RegistryFactory.new

end
