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

    class << self

      def has?(id)
        Persistent.exists?(id)
      end

      def fetch(id, default_value = marker)
        found = Persistent.find_by_id(id)
        return wrap(found) if found

        return yield if block_given?

        default_value.tap do |value|
          raise NotFoundError if value.eql?(marker)
        end
      end

      def global!
        @global_node = load_global_node()
        @global_node || raise(NoGlobalNode)
      end

      def global
        @global_node ||= create_global_node
      end

      def clear_global_cache
        @global_node = nil
      end

    private

      def create_global_node
        load_global_node || Node.wrap(Persistent.create!(global_node_properties))
      end

      def load_global_node
        persistent = Persistent.first(:conditions => global_node_properties)
        if persistent
          Node.wrap(persistent)
        end
      end

      def global_node_properties
        {
          :securable_type => AccessControl.global_securable_type,
          :securable_id   => AccessControl.global_securable_id
        }
      end

      def marker
        @marker ||= Object.new
      end
    end

    delegate :block, :id, :id=, :securable_type, :securable_type=,
             :securable_id, :securable_id=, :to => :persistent

    def self.wrap(object)
      allocate.tap do |new_node|
        new_node.instance_variable_set("@persistent", object)
      end
    end

    def initialize(properties = {})
      properties.each do |name, value|
        public_send("#{name}=", value)
      end
    end

    def self.store(properties)
      persistent = Node::Persistent.create!(properties)
      wrap(persistent)
    end

    def persistent
      @persistent ||= Node::Persistent.new
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

    def assignments_with_roles(filter_roles)
      assignments.with_roles(filter_roles)
    end

    def global?
      id == AccessControl.global_node_id
    end

    # after_create :set_default_roles
    # before_destroy :destroy_dependant_assignments

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

    def destroy_dependant_assignments
      AccessControl.manager.without_assignment_restriction do
        assignments.each(&:destroy)
      end
    end

    def set_default_roles
      AccessControl.config.default_roles_on_create.each do |role_name|
        next unless role = Role.find_by_name(role_name)

        AccessControl.manager.principal_ids.each do |principal_id|
          r = assignments.build(:role_id => role.id,
                                :principal_id => principal_id)
          r.skip_assignment_verification!
          r.save!
        end
      end
    end
  end
end
