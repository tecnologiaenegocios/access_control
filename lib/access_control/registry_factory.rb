require 'access_control/util'
require 'access_control/registry_factory/permission'
require 'backports'

module AccessControl
  class RegistryFactory
    def initialize(permission_factory = Permission.public_method(:new))
      @permission_factory = permission_factory
    end

    def clear
      @permissions = nil
      @indexed_permissions = nil
    end

    def store(name)
      new_permission = (permissions[name] ||= @permission_factory.call(name))

      yield(new_permission) if block_given?

      indexes.each do |index_name|
        add_permission_to_index(new_permission, index_name)
      end

      collection_indexes.each do |index_name|
        add_permission_to_collection_index(new_permission, index_name)
      end

      new_permission
    end

    def unstore(name)
      permission = permissions[name]

      indexes.each do |index_name|
        remove_permission_from_index(permission, index_name)
      end

      collection_indexes.each do |index_name|
        remove_permission_from_index(permission, index_name)
      end

      permissions.delete(name)
    end

    attr_writer :permission_manager
    def permission_manager
      @permission_manager ||= Role
    end

    def destroy(permission)
      permission_manager.destroy_permission(permission)
    end

    def add_index(index)
      indexes << index
      all.each do |permission|
        add_permission_to_index(permission, index)
      end
    end

    def add_collection_index(index)
      collection_indexes << index
      all.each do |permission|
        add_permission_to_collection_index(permission, index)
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

    def fetch(name, default=_marker)
      found = self[name]
      return found if found
      return yield if block_given?
      raise NotFoundError, "permission not found: #{name}" if default.eql?(_marker)
      default
    end

    def fetch_all(names)
      names.map { |name| fetch(name) }
    end

    def Permission(name_or_permission)
      if name_or_permission.kind_of?(String)
        fetch(name_or_permission)
      elsif name_or_permission.kind_of?(Symbol)
        fetch(name_or_permission.to_s)
      elsif all.include?(name_or_permission)
        name_or_permission
      else
        raise "Not a permission: #{name_or_permission}"
      end
    end

  private

    def indexes
      @indexes ||= Set.new
    end

    def collection_indexes
      @collection_indexes ||= Set.new
    end

    def permissions
      @permissions ||= Hash.new
    end

    def permissions_by(key)
      @indexed_permissions      ||= Hash.new
      @indexed_permissions[key] ||= Hash.new { |h, k| h[k] = Set.new }
    end

    def add_permission_to_collection_index(permission, index_name)
      return unless permission.respond_to?(index_name)
      collection = permission.send(index_name)

      collection.each do |value|
        add_permission_to_index(permission, index_name, value)
      end
    end

    def add_permission_to_index(permission, index_name, index_value = nil)
      index_value ||= permission.respond_to?(index_name) &&
                        permission.send(index_name)

      unless index_value.nil?
        indexed_permissions = permissions_by(index_name)
        indexed_permissions[index_value] << permission
      end
    end

    def remove_permission_from_index(permission, index_name)
      indexed_permissions = permissions_by(index_name)
      empty = []
      indexed_permissions.each do |index_value, permissions|
        permissions.delete(permission)
        if permissions.empty?
          empty << index_value
        end
      end
      empty.each { |index_value| indexed_permissions.delete(index_value) }
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
      if indexes.include?(name)
        permissions_by(name)[value]
      elsif collection_indexes.include?(name)
        collection_values = value

        Util.flat_set(collection_values) do |collection_value|
          permissions_by(name)[collection_value]
        end
      else
        all.each_with_object(Set.new) do |permission, permissions_set|
          if permission.respond_to?(name) && permission.send(name) == value
            permissions_set.add(permission)
          end
        end
      end
    end

    def _marker
      @_marker ||= Object.new
    end
  end
end
