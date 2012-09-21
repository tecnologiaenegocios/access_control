require 'access_control/manager'
require 'access_control/null_manager'
require 'access_control/securable'
require 'access_control/inheritance'
require 'access_control/registry'
require 'access_control/macros'
require 'access_control/controller_security'

module AccessControl

  MANAGER_THREAD_KEY = :ac_manager

  def self.manager
    if AccessControl.disabled?
      @null_manager ||= NullManager.new
    else
      Thread.current[MANAGER_THREAD_KEY] ||= Manager.new
    end
  end

  def self.no_manager
    Thread.current[MANAGER_THREAD_KEY] = nil
  end

  def self.global_node_id
    global_node.id
  end

  def self.global_node
    Node.global
  end

  def self.global_securable_type
    GlobalRecord.name
  end

  def self.global_securable_id
    GlobalRecord.instance.id
  end

  def self.anonymous_id
    anonymous.id
  end

  def self.anonymous
    Principal.anonymous
  end

  def self.anonymous_subject_type
    AnonymousUser.name
  end

  def self.anonymous_subject_id
    AnonymousUser.instance.id
  end

  def self.unrestrict_method(klass, method_name)
    method_name = method_name.to_sym

    klass.class_eval do
      alias_method :"unstrusted_#{method_name}", method_name

      define_method(method_name) do |*args, &block|
        AccessControl.manager.trust do
          send(:"unstrusted_#{method_name}", *args, &block)
        end
      end
    end

    mark_method_as_unrestricted(klass, method_name)
  end

  def self.unrestricted_method?(klass, method_name)
    klass.instance_exec(method_name.to_sym) do |m|
      methods = (@__access_control_unrestricted_methods__ || Set.new)
      methods.include?(m)
    end
  end

  def self.mark_method_as_unrestricted(klass, method_name)
    klass.instance_exec(method_name.to_sym) do |m|
      @__access_control_unrestricted_methods__ ||= Set.new
      @__access_control_unrestricted_methods__ << m
    end
  end
  private_class_method :mark_method_as_unrestricted

  def self.disable!
    @disabled = true
  end

  def self.enable!
    @disabled = false
  end

  def self.disabled?
    !!@disabled
  end

  def self.clear_parent_relationships!
    AccessControl.ac_parents.truncate
  end

  def self.clear_blocked_parent_relationships!
    AccessControl.ac_parents.
      filter(:child_id => Node::Persistent.blocked.select(:id)).
      delete
  end

  def self.default_batch_size= value
    @default_batch_size = value
  end

  def self.default_batch_size
    @default_batch_size ||= 500
  end

  def self.refresh_parents_of(securable)
    return if AccessControl.disabled?
    AccessControl::NodeManager.refresh_parents_of(securable)
  end

  def self.rebuild_parent_relationships(securable_class)
    AccessControl.transaction do
      Inheritance.inheritances_of(securable_class).each do |inheritance|
        relationships = inheritance.relationships

        if relationships.kind_of?(Sequel::Dataset)
          to_insert = relationships.filter(~{
            [:parent_nodes__id, :child_nodes__id] => \
            AccessControl.ac_parents.select(:parent_id, :child_id)
          })

          ac_parents.import([:parent_id, :child_id],
                            to_insert.select(:parent_nodes__id,
                                             :child_nodes__id))
        else
          relationships.each_slice(default_batch_size) do |partition|
            tuples = partition.map { |r| [r[:parent_id], r[:child_id]] }
            existing = ac_parents.filter([:parent_id, :child_id] => tuples)
            existing.delete

            ac_parents.multi_insert(partition)
          end
        end
      end
    end
  end

  def self.registry
    AccessControl::Registry
  end

  def self.clear
    AccessControl::ControllerSecurity.clear
    AccessControl::Macros.clear
    AccessControl::Registry.clear
  end

  def self.reset
    clear
    AccessControl::Inheritance.clear
  end

  class GlobalRecord
    include Singleton
    def id
      1
    end
  end

  class AnonymousUser
    include Singleton
    def id
      1
    end
  end
end
