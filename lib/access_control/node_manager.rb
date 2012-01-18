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

    def initialize(node)
      @node = node
    end

    def can_update!
      manager.can!(update_permissions, @node)
    end

    def refresh_parents
      added_parents = new_persisted_parent_nodes
      deleted_parents = removed_persisted_parent_nodes

      added_parents.each do |parent_node|
        manager.can!(create_permissions, parent_node)
        inheritance_manager.add_parent(parent_node)
      end

      deleted_parents.each do |parent_node|
        manager.can!(destroy_permissions, parent_node)
        inheritance_manager.del_parent(parent_node)
      end

      role_propagation(added_parents).propagate!
      role_propagation(deleted_parents).depropagate!
    end

    def disconnect
      current_parent_nodes.each do |parent_node|
        manager.can!(destroy_permissions, parent_node)
      end
      role_propagation(current_parent_nodes).depropagate!
      inheritance_manager.del_all_parents
      inheritance_manager.del_all_children
    end

    def block
      role_propagation(inheritance_manager.parents).depropagate!
      inheritance_manager.del_all_parents
    end

    def unblock
      final_parent_nodes.each do |parent_node|
        inheritance_manager.add_parent(parent_node)
      end

      role_propagation(final_parent_nodes).propagate!
    end

  private

    def manager
      AccessControl.manager
    end

    def update_permissions
      securable_class.permissions_required_to_update
    end

    def create_permissions
      securable_class.permissions_required_to_create
    end

    def destroy_permissions
      securable_class.permissions_required_to_destroy
    end

    def securable_class
      @node.securable_class
    end

    def new_persisted_parent_nodes
      final_parent_nodes - current_parent_nodes
    end

    def removed_persisted_parent_nodes
      current_parent_nodes - final_parent_nodes
    end

    def current_parent_nodes
      @current_parent_nodes ||= inheritance_manager.parents
    end

    def inheritance_manager
      @inheritance_manager ||= Node::InheritanceManager.new(@node)
    end

    def final_parent_nodes
      @final_parent_nodes ||= parent_nodes.select(&:persisted?)
    end

    def parent_nodes
      securable_parents.map do |securable_parent|
        AccessControl::Node(securable_parent)
      end
    end

    def securable_parents
      methods = securable_class.inherits_permissions_from
      methods.each_with_object(Set.new) do |method_name, set|
        set.merge(Array[*securable.send(method_name)].compact)
      end
    end

    def securable
      @node.securable
    end

    def role_propagation(parents)
      RolePropagation.new(@node, parents)
    end
  end
end
