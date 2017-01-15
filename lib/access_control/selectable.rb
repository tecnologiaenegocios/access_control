require 'access_control/orm'

module AccessControl
  class Selectable
    attr_reader :main_type

    def initialize(main_type)
      @main_type = main_type
    end

    def subquery_sql(&permissions)
      subquery(&permissions).try(:sql)
    end

  private

    def subquery(&permissions)
      return if all_types_globally_permitted?(&permissions)

      subqueries = types.map { |type| type_subquery(type) }.reduce do |a, q|
        a.union(q, all: true, from_self: false)
      end

      recursions = types.map do |type|
        candidate_role_ids = role_ids(permissions.(type))

        anchor = ac_assignments
          .select(:node_id)
          .where(role_id: candidate_role_ids, principal_id: principal_ids)

        recursion = ac_parents
          .select(:child_id)
          .join(permitted_nodes_name(type), node_id: :parent_id)

        [type, anchor, recursion]
      end

      recursions.inject(subqueries) do |dataset, (type, anchor, recursion)|
        dataset.with_recursive(
          permitted_nodes_name(type), anchor, recursion, args: %i(node_id),
          union_all: false
        )
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

    def type_subquery(type)
      permissions = type.permissions_required_to_list
      if manager.can?(permissions, global_node)
        ORM.adapt_class(type).dataset
      else
        ac_nodes
          .select(:securable_id)
          .join(permitted_nodes_name(type), node_id: :id)
          .filter(securable_type: type.name)
      end
    end

    def permitted_nodes_name(type)
      :"ac_#{type.name.underscore.pluralize}"
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
