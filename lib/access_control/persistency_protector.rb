module AccessControl
  module PersistencyProtector
    class << self

      def track_parents(instance)
        parents = Parenter.parents_of(instance)
        set_tracked_parents(instance, parents)
      end

      def verify_attachment!(instance)
        existing_parents = get_tracked_parents(instance)
        current_parents = Parenter.parents_of(instance)
        added_parents = current_parents - existing_parents
        permissions = permissions_for(:create, instance)

        added_parents.each do |new_parent|
          manager.can!(permissions, new_parent)
        end
      end

      def verify_detachment!(instance)
        existing_parents = get_tracked_parents(instance)
        current_parents = Parenter.parents_of(instance)
        removed_parents = existing_parents - current_parents
        permissions = permissions_for(:destroy, instance)

        removed_parents.each do |old_parent|
          manager.can!(permissions, old_parent)
        end
      end

      def verify_update!(instance)
        manager.can!(permissions_for(:update, instance), instance)
      end

    private

      def get_tracked_parents(instance)
        instance.instance_variable_get(:@__tracked_parents__)
      end

      def set_tracked_parents(instance, parents)
        instance.instance_variable_set(:@__tracked_parents__, parents)
      end

      def manager
        AccessControl.manager
      end

      def permissions_for(type, instance)
        instance.class.send(:"permissions_required_to_#{type}")
      end
    end
  end
end
