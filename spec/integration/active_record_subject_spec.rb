require 'spec_helper'

describe "principal association" do
  include WithConstants

  let_active_record(:User) do
    include AccessControl::ActiveRecordSubject
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

  specify "the principal can be found later for that record" do
    subject.save!
    principal = AccessControl::Principal(subject)
    other_principal = AccessControl::Principal(User.first)
    other_principal.should == principal
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
      let_active_record(:User) { }

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

      specify "the principal can be found later for that record" do
        record = User.first
        record.save!
        principal = AccessControl::Principal(record)
        other_principal = AccessControl::Principal(User.first)
        other_principal.should == principal
      end
    end
  end
end
