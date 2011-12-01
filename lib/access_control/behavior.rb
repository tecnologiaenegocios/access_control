module AccessControl

  MANAGER_THREAD_KEY = :ac_manager

  class << self

    def manager
      Thread.current[MANAGER_THREAD_KEY] ||= Manager.new
    end

    def no_manager
      Thread.current[MANAGER_THREAD_KEY] = nil
    end

    def create_global_node!
      clear_global_node_cache
      ActiveRecord::Base.connection.execute("
        INSERT INTO `ac_nodes` (`securable_type`, `securable_id`)
        VALUES ('#{global_securable_type}', #{global_securable_id})
      ")
    end

    def clear_global_node_cache
      @global_node_cache = nil
    end

    def global_node_id
      global_node.id
    end

    def global_node
      @global_node_cache ||=
        begin
          node = Node.find(:first, :conditions => {
            :securable_type => global_securable_type,
            :securable_id   => global_securable_id
          })
          raise NoGlobalNode unless node
          node
        end
    end

  private

    def global_securable_type
      GlobalRecord.name
    end

    def global_securable_id
      GlobalRecord.instance.id
    end

  end

  class GlobalRecord
    include Singleton
    def ac_node
      AccessControl.global_node
    end
    def id
      1
    end
  end

end
