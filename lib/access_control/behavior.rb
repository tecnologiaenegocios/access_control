require 'access_control/manager'

module AccessControl

  MANAGER_THREAD_KEY = :ac_manager

  def self.manager
    Thread.current[MANAGER_THREAD_KEY] ||= Manager.new
  end

  def self.no_manager
    Thread.current[MANAGER_THREAD_KEY] = nil
  end

  def self.create_global_node!
    clear_global_node_cache
    Node.create!(:securable_type => global_securable_type,
                 :securable_id   => global_securable_id)
  end

  def self.clear_global_node_cache
    @global_node_cache = nil
  end

  def self.global_node_id
    global_node.id
  end

  def self.global_node
    @global_node_cache ||= load_global_node()
  end

  class << self
    private

    def load_global_node
      node = Node.first(:conditions => {
        :securable_type => global_securable_type,
        :securable_id   => global_securable_id
      })

      node || raise(NoGlobalNode)
    end

    def global_securable_type
      GlobalRecord.name
    end

    def global_securable_id
      GlobalRecord.instance.id
    end
  end

  class GlobalRecord
    include Singleton

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
