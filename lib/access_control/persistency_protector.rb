module AccessControl
  class PersistencyProtector
    def initialize(instance)
      @instance = instance
    end
    def verify!(action)
      permissions = permissions_for(action)
      if permissions.any?
        manager = AccessControl.manager
        manager.can!(permissions, @instance)
      end
    end
  private
    def permissions_for(action)
      @instance.class.send(:"permissions_required_to_#{action}")
    end
  end
end
