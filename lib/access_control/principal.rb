require 'access_control/persistable'
require 'access_control/ids'
require 'access_control/principal/persistent'

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

    class << self
      def persistent_model
        @persistent_model ||= ORM.adapt_class(Persistent)
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

      def for_subject(subject)
        properties = {
          :subject_type => subject.class.name,
          :subject_id   => subject.id,
        }

        persistent = Principal::Persistent.filter(properties).first

        return wrap(persistent) if persistent
        new(:subject_class => subject.class, :subject_id => subject.id)
      end

    private

      def create_anonymous_principal
        load_anonymous_principal ||
          wrap(Persistent.create(anonymous_properties))
      end

      def load_anonymous_principal
        persistent = Persistent.filter(anonymous_properties).first
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
      Role.unassign_all_from(self)
      super
    end
  end

  class UnrestrictablePrincipal

    include Singleton

    ID = -1

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
