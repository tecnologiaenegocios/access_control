module AccessControl

  class Principal < ActiveRecord::Base
    set_table_name :ac_principals
    belongs_to :subject, :polymorphic => true
    has_many :assignments,
             :class_name => 'AccessControl::Assignment',
             :dependent => :destroy

    def self.anonymous
      @anonymous ||= find_by_subject_type_and_subject_id(
        anonymous_subject_type,
        anonymous_subject_id
      )
    end

    def self.anonymous_id
      anonymous.id
    end

    def self.with_assignments
      ids_with_assignments = Assignment.all.map(&:principal_id).uniq

      scoped(:conditions => {:id => ids_with_assignments})
    end

    def anonymous?
      subject_type == self.class.anonymous_subject_type &&
        subject_id == self.class.anonymous_subject_id
    end

    def self.create_anonymous_principal!
      create!(
        :subject_type => anonymous_subject_type,
        :subject_id => anonymous_subject_id
      )
    end

    def self.anonymous_subject_type
      AnonymousUser.name
    end

    def self.anonymous_subject_id
      0
    end

    def self.clear_anonymous_principal_cache
      @anonymous = nil
    end

  end

  class AnonymousUser

    include Singleton

    def self.find(*args)
      return instance
    end

    def ac_principal
      Principal.anonymous
    end

    def id
      Principal.anonymous_subject_id
    end

  end

  class UnrestrictablePrincipal

    include Singleton

    ID = Object.new

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
