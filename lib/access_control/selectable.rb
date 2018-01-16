require 'access_control/orm'

module AccessControl
  class Selectable
    attr_reader :main_type

    def initialize(main_type)
      @main_type = main_type
    end

    def subquery_sql(&permissions)
      build_subquery(&permissions).try(:sql)
    end

  private

    def build_subquery(&permissions)
      return if all_types_globally_permitted?(&permissions)
      types.map { |type| subquery(type, permissions.(type)) }.reduce do |a, q|
        a.union(q, all: true, from_self: false)
      end
    end

    def all_types_globally_permitted?(&permissions)
      types.all? { |t| manager.can?(permissions.(t), global_node) }
    end

    def types
      main_type.instance_eval do
        break @__AccessControl_Restriction_self_and_subclasses__ ||=
          ObjectSpace.each_object(singleton_class).select do |s|
            # Instance singleton classes must not be returned.  They are
            # exposed in Ruby 2.3+.  Ignore all singleton classes as well.
            !s.singleton_class?
          end
      end
    end

    def subquery(type, permissions)
      if manager.can?(permissions, global_node)
        return ORM.adapt_class(type).dataset
      end

      ancestors = Sequel[:"ac_ancestors_#{type.name.underscore.pluralize}"]

      anchor = ac_nodes
        .select(:securable_id, :id)
        .where(securable_type: type.name)

      recursion = ac_parents
        .select(ancestors[:securable_id], :parent_id)
        .join(ancestors, ancestor_id: :child_id)

      ac_assignments
        .join(ancestors, ancestor_id: :node_id)
        .where(role_id: role_ids(permissions), principal_id: principal_ids)
        .with_recursive(
          ancestors, anchor, recursion,
          args: %i(securable_id ancestor_id),
          union_all: false
        )
        .select(ancestors[:securable_id])
    end

    def db
      AccessControl.db
    end

    def ac_nodes
      AccessControl.ac_nodes
    end

    def ac_assignments
      AccessControl.ac_assignments
    end

    def ac_parents
      AccessControl.ac_parents
    end

    def manager
      AccessControl.manager
    end

    def global_node
      AccessControl.global_node
    end

    def role_ids(permissions)
      Role.for_all_permissions(permissions).map(&:id)
    end

    def principal_ids
      manager.principals.map(&:id)
    end
  end
end
