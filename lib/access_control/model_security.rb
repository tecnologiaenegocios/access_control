require 'access_control/configuration'

module AccessControl
  module ModelSecurity

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods

      def restrict_association association_name
        restricted_associations.add(association_name)
      end

      def restrict_all_associations!
        reflections.each do |name, reflection|
          if reflection.macro == :belongs_to
            restricted_associations.add(name.to_sym)
          end
        end
      end

      def unrestrict_association association_name
        restricted_associations.delete(association_name)
      end

      def unrestrict_all_associations!
        restricted_associations.clear
      end

      def association_restricted? association_name
        restricted_associations.include?(association_name)
      end

      def restricted_associations
        return @ac_restricted_associations if @ac_restricted_associations
        restricted_associations = Set.new
        if AccessControl.config.restrict_belongs_to_association
          reflections.each do |name, reflection|
            if reflection.macro == :belongs_to
              restricted_associations.add(name.to_sym)
            end
          end
        end
        @ac_restricted_associations = restricted_associations
      end

    end

  end
end
