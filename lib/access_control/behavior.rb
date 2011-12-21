require 'access_control/manager'
require 'access_control/securable'

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

    def ac_node
      AccessControl.global_node
    end

    def id
      1
    end
  end

end
