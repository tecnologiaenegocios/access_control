require 'spec_helper'
require 'access_control/principal'

module AccessControl
  describe Principal do

    let(:manager) { Manager.new }

    before do
      class Object::SubjectObj < ActiveRecord::Base
        def self.columns
          []
        end
      end
      AccessControl.stub(:manager).and_return(manager)
    end

    after do
      Object.send(:remove_const, 'SubjectObj')
    end

    it "can be created with valid attributes" do
      Principal.create!(:subject => stub_model(SubjectObj))
    end

    it "destroys assignments when it is destroyed" do
      r = Principal.create!(:subject => stub_model(SubjectObj))
      manager.stub(:can_assign_or_unassign?).and_return(true)
      Assignment.create!(:principal_id => r.id,
                         :node_id => 0, :role_id => 0)
      r.destroy
      Assignment.count.should == 0
    end

    describe ".with_assignments" do
      def build_assignment(principal_id = nil)
        principal_id  ||= 0

        @counter ||= 0
        @counter += 1

        Assignment.create!(:principal_id => principal_id,
          :role_id => @counter, :node_id => @counter)
      end

      def build_principal
        Principal.create!(:subject_type => "foo", :subject_id => 1234)
      end

      it "returns principals that have at least one assignment" do
        principal = build_principal()
        build_assignment(principal.id)

        Principal.with_assignments.should include principal
      end

      it "doesn't return principals that have no assignments" do
        principal = build_principal()
        Principal.with_assignments.should_not include principal
      end

      it "doesn't return duplicated principals" do
        principal = build_principal()
        build_assignment(principal.id)
        build_assignment(principal.id)

        Principal.with_assignments.count.should == 1
      end
    end
    describe "anonymous principal" do

      let(:anonymous_principal) do
        anonymous_subject_type = Principal.anonymous_subject_type
        anonymous_subject_id = Principal.anonymous_subject_id
        Principal.find_by_subject_type_and_subject_id(
          anonymous_subject_type, anonymous_subject_id
        )
      end

      before do
        Principal.clear_anonymous_principal_cache
      end

      it "creates the anonymous principal" do
        Principal.create_anonymous_principal!
      end

      it "can return the anonymous principal object" do
        Principal.create_anonymous_principal!
        Principal.anonymous.should == anonymous_principal
      end

      it "can return the anonymous principal id" do
        Principal.create_anonymous_principal!
        Principal.anonymous_id.should == anonymous_principal.id
      end

      it "returns nil if there's no anonymous principal" do
        Principal.anonymous.should be_nil
      end

      it "caches the anonymous principal" do
        Principal.create_anonymous_principal!
        Principal.anonymous
        Principal.should_not_receive(:find)
        Principal.anonymous
      end

      describe "predicate method #anonymous?" do

        it "returns true if the principal is the anonymous principal" do
          Principal.create_anonymous_principal!
          Principal.anonymous.should be_anonymous
        end

        it "returns false otherwise" do
          principal = Principal.create!(:subject => stub_model(SubjectObj))
          principal.should_not be_anonymous
        end

      end

      describe "anonymous subject" do

        before do
          Principal.create_anonymous_principal!
        end

        it "returns a valid subject" do
          Principal.anonymous.subject.should_not be_nil
        end

        it "has id == Principal.anonymous_subject_id" do
          Principal.anonymous.subject.id.
            should == Principal.anonymous_subject_id
        end

        it "returns the principal" do
          AnonymousUser.instance.ac_principal.should == Principal.anonymous
        end

      end

    end

    describe "unrestrictable subject" do

      it "returns the principal" do
        UnrestrictableUser.instance.ac_principal.
          should == UnrestrictablePrincipal.instance
      end

    end

  end
end
