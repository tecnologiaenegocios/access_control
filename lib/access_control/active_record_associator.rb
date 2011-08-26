module AccessControl
  module ActiveRecordAssociator

    def self.included(base)
      base.extend(ClassMethods)
      base.class_eval do
        after_create :create_access_control_objects
      end
    end

    module ClassMethods

      def associate_with_access_control(name, class_name, polymorphic_name)
        has_one(name, :class_name => class_name, :as => polymorphic_name,
                :dependent => :destroy)
        (@access_control_associations ||= {})[name] = [class_name,
                                                       polymorphic_name]
      end

    end

    def create_access_control_objects
      assocs = self.class.instance_variable_get('@access_control_associations')
      assocs.each do |name, (class_name, polymorphic_name)|
        class_name.constantize.create!(polymorphic_name.to_sym => self)
      end
    end

  end
end
