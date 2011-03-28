module AccessControl
  class Principal < ActiveRecord::Base
    set_table_name :ac_principals
    belongs_to :subject, :polymorphic => true

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
      'AnonymousPrincipal'
    end

    def self.anonymous_subject_id
      0
    end

    def self.securable?
      false
    end
  end
end
