require 'access_control/util'

module AccessControl
  class RegistryFactory

    def clear_registry
      @permissions = nil
      @indexed_permissions = nil
    end

    def store(name)
      Permission.new(name).tap do |new_permission|
        yield(new_permission) if block_given?

        permissions[name] = new_permission
        indexes.each do |index_name|
          add_permission_to_index(new_permission, index_name)
        end
      end
    end

    def add_index(index)
      indexes << index
      all.each do |permission|
        add_permission_to_index(permission, index)
      end
    end

    def [](name)
      permissions[name]
    end

    def all
      permissions.values
    end

    def query(criteria = {})
      filtered_by_criteria = filter_by_criteria(criteria)

      if block_given?
        filtered_by_criteria.delete_if { |perm| not yield(perm) }
      else
        filtered_by_criteria
      end
    end

  private

    def indexes
      @indexes ||= Set.new
    end

    def permissions
      @permissions ||= Hash.new
    end

    def permissions_by(key)
      @indexed_permissions      ||= Hash.new
      @indexed_permissions[key] ||= Hash.new { |h, k| h[k] = Set.new }
    end

    def add_permission_to_index(permission, index_name)
      index_value = permission.send(index_name)
      unless index_value.nil?
        indexed_permissions = permissions_by(index_name)
        indexed_permissions[index_value] << permission
      end
    end

    def filter_by_criteria(criteria)
      return Set.new(all) if criteria.empty?

      initial_set = permissions_matching_criterion(*criteria.shift)

      criteria.inject(initial_set) do |previous_match, (key, value)|
        break Set.new if previous_match.empty?

        current_match = permissions_matching_criterion(key, value)

        break Set.new if current_match.empty?

        previous_match & current_match
      end
    end

    def permissions_matching_criterion(name, value)
      if name == :name
        permission = permissions[value]
        permission ? Set[permission] : Set.new
      elsif indexes.include?(name)
        permissions_by(name)[value]
      else
        all.each_with_object(Set.new) do |permission, permissions_set|
          if permission.respond_to?(name) && permission.send(name) == value
            permissions_set.add(permission)
          end
        end
      end
    end
  end

  Registry = RegistryFactory.new
end
