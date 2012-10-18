require 'spec_helper'

describe "principal association" do
  include WithConstants

  let_constant(:user_class) do
    new_class(:User, ActiveRecord::Base) do
      include AccessControl::ActiveRecordSubject
    end
  end

  subject { User.new }

  it "associates a principal for a given active record object" do
    AccessControl::Principal(subject).should be_a(AccessControl::Principal)
  end

  specify "once the principal is computed, it is cached" do
    old_result = AccessControl::Principal(subject)
    new_result = AccessControl::Principal(subject)
    old_result.should be new_result
  end

  it "persists the principal when the record is created" do
    principal = AccessControl::Principal(subject)
    subject.save!
    principal.should be_persisted
  end

  specify "the principal is saved with correct attributes" do
    subject.save!
    principal = AccessControl::Principal(subject)
    principal.subject_type.should == 'User'
    principal.subject_id.should   == subject.id
  end

  it "destroys the principal when the record is destroyed" do
    subject.save!
    principal = AccessControl::Principal(subject)
    principal.should_receive(:destroy)
    subject.destroy
  end

  describe "update" do
    let(:principal) { AccessControl::Principal(subject) }

    context "the record already has a principal" do
      before do
        subject.save!
        principal.persist!
      end

      it "doesn't persist the principal again" do
        principal.should_not_receive(:persist)
        subject.save!
      end
    end

    context "the record has no principal yet" do
      let_constant(:user_class) { new_class(:User, ActiveRecord::Base) }

      before do
        subject.save!
        User.class_eval do
          include AccessControl::ActiveRecordSubject
        end
      end

      it "persists the principal" do
        record = User.first
        principal = AccessControl::Principal(record)
        record.save!
        principal.should be_persisted
      end

      specify "the principal is saved with correct attributes" do
        record = User.first
        record.save!
        principal = AccessControl::Principal(subject)
        principal.subject_type.should == 'User'
        principal.subject_id.should   == record.id
      end
    end
  end

  describe "in subclasses" do
    let_constant(:subuser_class) { new_class(:SubUser, user_class) }
    subject { SubUser.new }

    specify "the principal subject_type's is set to the subclass' name" do
      subject.save!
      reloaded = SubUser.first
      principal = AccessControl::Principal(reloaded)
      principal.subject_type.should == 'SubUser'
      principal.subject_id.should   == reloaded.id
    end
  end
end
