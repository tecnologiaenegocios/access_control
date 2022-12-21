module AccessControl
  class NodeManager
    class << self
      def refresh_parents_of(node)
        new(node).refresh_parents
      end

      def can_update!(node)
        new(node).can_update!
      end

      def disconnect(node)
        new(node).disconnect
      end

      def block(node)
        new(node).block
      end

      def unblock(node)
        new(node).unblock
      end
    end

    attr_writer :inheritance_manager, :manager
    attr_reader :node

    def initialize(node)
      @node = AccessControl::Node(node)
    end

    def can_update!
      manager.can!(permissions_to_update, node)
    end

    def refresh_parents
      new_parents     = nodes_of_securable_parents - cached_parents
      deleted_parents = cached_parents - nodes_of_securable_parents

      if new_parents.any?
        add_to_parents_cache(new_parents)
      end

      if deleted_parents.any?
        remove_from_parents_cache(deleted_parents)
      end
    end

    def disconnect
      parents = cached_parents

      parents.each do |parent_node|
        manager.can!(permissions_to_destroy, parent_node)
      end

      inheritance_manager.del_all_parents
      inheritance_manager.del_all_children
    end

    def block
      inheritance_manager.del_all_parents
    end

    def unblock
      nodes_of_securable_parents.each do |parent_node|
        inheritance_manager.add_parent(parent_node)
      end
    end

  private

    def add_to_parents_cache(parents)
      parents.each do |parent_node|
        manager.can!(permissions_to_create, parent_node)
        inheritance_manager.add_parent(parent_node)
      end
    end

    def remove_from_parents_cache(parents)
      parents.each do |parent_node|
        manager.can!(permissions_to_destroy, parent_node)
        inheritance_manager.del_parent(parent_node)
      end
    end

    def manager
      @manager ||= AccessControl.manager
    end

    def permissions_to_update
      node.securable_class.permissions_required_to_update
    end

    def permissions_to_create
      node.securable_class.permissions_required_to_create
    end

    def permissions_to_destroy
      node.securable_class.permissions_required_to_destroy
    end

    def cached_parents
      @cached_parents ||= inheritance_manager.parents
    end

    def nodes_of_securable_parents
      @nodes_of_securable_parents ||=
        Inheritance.parent_nodes_of(node.securable).tap do |nodes|
          nodes.each do |node|
            unless node.persisted?
              AccessControl.manager.trust { node.persist! }
            end
          end
        end
    end

    def inheritance_manager
      @inheritance_manager ||= Node::InheritanceManager.new(node)
    end
  end
end
