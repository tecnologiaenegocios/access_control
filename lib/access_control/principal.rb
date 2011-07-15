require 'access_control/assignment'

module AccessControl

  class Principal < ActiveRecord::Base
    set_table_name :ac_principals
    belongs_to :subject, :polymorphic => true
    has_many :assignments,
             :class_name => Assignment.name,
             :dependent => :destroy

    def self.anonymous
      find_by_subject_type_and_subject_id(
        anonymous_subject_type,
        anonymous_subject_id
      )
    end

    def self.anonymous_id
      anonymous.id
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

    def self.unrestrictable
      find_by_subject_type_and_subject_id(
        unrestrictable_subject_type,
        unrestrictable_subject_id
      )
    end

    def self.unrestrictable_id
      unrestrictable.id
    end

    def unrestrictable?
      subject_type == self.class.unrestrictable_subject_type &&
        subject_id == self.class.unrestrictable_subject_id
    end

    def self.create_unrestrictable_principal!
      create!(
        :subject_type => unrestrictable_subject_type,
        :subject_id => unrestrictable_subject_id
      )
    end

    def self.unrestrictable_subject_type
      UnrestrictableUser.name
    end

    def self.unrestrictable_subject_id
      0
    end

    def self.securable?
      false
    end
  end

  class AnonymousUser

    include Singleton

    def self.find(*args)
      return instance
    end

    def principal
      Principal.anonymous
    end

    def id
      Principal.anonymous_subject_id
    end

  end

  class UnrestrictableUser

    include Singleton

    def self.find(*args)
      return instance
    end

    def principal
      Principal.unrestrictable
    end

    def id
      Principal.unrestrictable_subject_id
    end

  end

end
