require 'access_control/manager'
require 'access_control/securable'
require 'access_control/inheritance'

module AccessControl

  MANAGER_THREAD_KEY = :ac_manager

  def self.manager
    Thread.current[MANAGER_THREAD_KEY] ||= Manager.new
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

  def self.setup_parent_relationships(securable_class)
    Inheritance.inheritances_of(securable_class).each do |inheritance|
      ac_parents.import([:parent_id, :child_id], inheritance.relationships)
    end
  end

  class GlobalRecord
    include Singleton
    include Securable

    def self.unrestricted_find(argument, *)
      case argument
        when :first, :last, instance.id
          instance
        when :all
          Set[instance]
      end
    end

    def id
      1
    end
  end

  class AnonymousUser
    include Singleton

    def self.unrestricted_find(argument, *)
      case argument
        when :first, :last, instance.id
          instance
        when :all
          Set[instance]
      end
    end

    def id
      1
    end

  end
end
