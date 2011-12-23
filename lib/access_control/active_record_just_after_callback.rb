module AccessControl
  module ActiveRecordJustAfterCallback

    # This is patch code to introduce ActiveRecord 2.x to the world of
    # just_after_* callbacks.  In ActiveRecord 3.x this is easier, since we
    # could provide the following API:
    #
    #   def just_after_create(&callback)
    #     set_callback(:create, :after, :prepend => false, &callback)
    #   end
    #
    # Note: +:prepend => false+, not +true+, because the order of after
    # callbacks is reversed in newer versions of ActiveSupport::Callback.
    #
    # The usage would remain the same, as follows:
    #
    #   class User < ActiveRecord::Base
    #     include ActiveRecordJustAfterCallback
    #
    #     just_after_create do
    #       Group.find(self.default_group_id).add(self)
    #     end
    #   end

    def self.included(base)
      base.extend(ClassMethods)
      base.class_eval do
        def create_without_callbacks
          super
          self.class.just_after_callback_chains.execute(self, :create)
        end

        def update_without_callbacks
          super
          self.class.just_after_callback_chains.execute(self, :update)
        end

        def destroy_without_callbacks
          super
          self.class.just_after_callback_chains.execute(self, :destroy)
        end
      end
    end

    class Chains
      def [] name
        storage[name] ||= []
      end

      def storage
        @storage ||= {}
      end

      def execute instance, name
        self[name].each do |callback|
          instance.instance_eval(&callback)
        end
      end
    end

    module ClassMethods
      def just_after_create &callback
        just_after_callback_chains[:create] << callback
      end

      def just_after_update &callback
        just_after_callback_chains[:update] << callback
      end

      def just_after_destroy &callback
        just_after_callback_chains[:destroy] << callback
      end

      def just_after_callback_chains
        @__just_after_callback_chains__ ||= Chains.new
      end
    end
  end
end
