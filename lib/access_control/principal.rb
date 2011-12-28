require 'access_control/persistable'

module AccessControl
  def AccessControl.Principal(object)
    if object.kind_of?(AccessControl::Principal)
      object
    elsif object.respond_to?(:ac_principal)
      object.ac_principal
    else
      raise UnrecognizedSubject
    end
  end

  class Principal
    include Persistable

    class Persistent < ActiveRecord::Base
      set_table_name :ac_principals
    end

    class << self
      def persistent_model
        Persistent
      end

      def anonymous!
        @anonymous = load_anonymous_principal
        @anonymous || raise(NoAnonymousPrincipal)
      end

      def anonymous
        @anonymous ||= create_anonymous_principal
      end

      def clear_anonymous_cache
        @anonymous = nil
      end

    private

      def create_anonymous_principal
        load_anonymous_principal ||
          wrap(Persistent.create!(anonymous_properties))
      end

      def load_anonymous_principal
        persistent = Persistent.first(:conditions => anonymous_properties)
        wrap(persistent) if persistent
      end

      def anonymous_properties
        {
          :subject_type => AccessControl.anonymous_subject_type,
          :subject_id   => AccessControl.anonymous_subject_id
        }
      end
    end

    def initialize(properties={})
      properties.delete(:subject_type) if properties[:subject_class]
      super(properties)
    end

    def subject_class= klass
      self.subject_type = klass.name
      @subject_class    = klass
    end

    def subject_class
      @subject_class ||= subject_type.constantize
    end

    def subject
      @subject ||= subject_class.unrestricted_find(subject_id)
    end

    def anonymous?
      id == AccessControl.anonymous_id
    end

    def destroy
      AccessControl.manager.without_assignment_restriction do
        Role.assigned_to(self).each { |role| role.unassign_from(self) }
      end
      super
    end
  end

  class UnrestrictablePrincipal

    include Singleton

    ID = Object.new.object_id

    def id
      ID
    end

  end

  class UnrestrictableUser

    include Singleton

    def ac_principal
      UnrestrictablePrincipal.instance
    end

  end
end
