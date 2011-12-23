require 'access_control/exceptions'
require 'access_control/ids'
require 'access_control/inheritance'
require 'access_control/configuration'

module AccessControl

  def AccessControl.Node(object)
    if object.kind_of?(AccessControl::Node)
      object
    elsif object.kind_of?(AccessControl::Securable)
      object.ac_node
    else
      raise(UnrecognizedSecurable)
    end
  end

  class Node
    require 'access_control/node/class_methods'
    extend Node::ClassMethods

    def self.with_type(type)
      scope = Node::Persistent.with_type(type)
      Node::WrapperScope.new(scope)
    end

    delegate :block, :id, :id=, :securable_type, :securable_type=,
             :securable_id, :securable_id=, :to => :persistent

    def initialize(properties = {})
      properties.each do |name, value|
        public_send("#{name}=", value)
      end
    end

    def persistent
      @persistent ||= Node::Persistent.new
    end

    def persist
      should_set_default_roles = (not persisted?)
      persistent.save!

      assignments.each do |assignment|
        assignment.id = self.id
        assignment.save!
      end

      if should_set_default_roles
        set_default_roles
      end
    end

    def persisted?
      not persistent.new_record?
    end

    def ==(other)
      if other.kind_of?(self.class)
        other.persistent == persistent
      else
        false
      end
    end

    def block= value
      AccessControl.manager.can!('change_inheritance_blocking', self)
      persistent.block = value
    end

    def assignments_with_roles(roles)
      if persisted?
        assignments.with_roles(roles)
      else
        assignments.select { |assignment| roles.include?(assignment.role) }
      end
    end

    def assignments
      @assignments ||=
        if persisted?
          Assignment.with_node_id(persistent.id)
        else
          Array.new
        end
    end

    def global?
      id == AccessControl.global_node_id
    end

    def destroy
      AccessControl.manager.without_assignment_restriction do
        persistent.destroy
        assignments.each(&:destroy)
      end
    end

    def securable
      @securable ||= securable_class.unrestricted_find(securable_id)
    end

    def securable_class=(klass)
      self.securable_type = klass.name
      @securable_class    = klass
    end

    def securable_class
      @securable_class ||= securable_type.constantize
    end

    attr_writer :inheritance_manager
    def inheritance_manager
      @inheritance_manager ||= InheritanceManager.new(self)
    end

    def ancestors
      strict_ancestors.add(self)
    end

    def strict_ancestors
      guard_against_block(:by_returning => :global_node) do
        inheritance_manager.ancestors
      end
    end

    def unblocked_ancestors
      strict_unblocked_ancestors.add(self)
    end

    def strict_unblocked_ancestors
      guard_against_block(:by_returning => :global_node) do
        filter = proc { |node| not node.block }
        inheritance_manager.filtered_ancestors(filter)
      end
    end

    def parents
      guard_against_block(:by_returning => Set.new) do
        inheritance_manager.parents
      end
    end

    def unblocked_parents
      guard_against_block(:by_returning => Set.new) do
        Set.new parents.reject(&:block)
      end
    end

    def inspect
      id = "id: #{self.id.inspect}"
      securable_desc = ""
      if securable_id
        securable_desc = "securable: #{securable_type}(#{securable_id})"
      else
        securable_desc = "securable_type: #{securable_type.inspect}"
      end

      blocked = block ? "blocked": nil

      body = [id, securable_desc, blocked].compact.join(", ")

      "#<AccessControl::Node #{body}>"
    end

  private
    def guard_against_block(arguments = {})
      default_value = arguments.fetch(:by_returning)

      if block
        if default_value == :global_node
          Set[Node.global]
        else
          default_value
        end
      else
        yield
      end
    end

    def set_default_roles
      principals_ids = AccessControl.manager.principal_ids

      default_roles  = AccessControl.config.default_roles_on_create
      roles_ids = default_roles.map do |role_name|
        role = Role.find_by_name(role_name)
        role && role.id
      end
      roles_ids.compact!

      roles_ids.product(principals_ids).map do |role_id, principal_id|
        assignment = Assignment.new(:role_id => role_id,
                      :principal_id => principal_id, :node_id => self.id)

        assignments << assignment
        assignment.skip_assignment_verification!
        assignment.save!
      end

    end
  end
end
