require 'spec_helper'
require 'access_control/principal'

module AccessControl
  describe ".Principal" do
    specify "when the argument is a Principal, returns it untouched" do
      principal = Principal.new
      return_value = AccessControl.Principal(principal)

      return_value.should be principal
    end

    specify "when the argument responds to .ac_principal, its return value "\
            "is returned" do
      principal = Principal.new
      subject   = stub('Subject', :ac_principal => principal)

      return_value = AccessControl.Principal(subject)
      return_value.should be principal
    end

    it "launches Exception for non-recognized arguments" do
      random_object = stub.as_null_object

      lambda {
        AccessControl.Principal(random_object)
      }.should raise_exception(AccessControl::UnrecognizedSubject)
    end
  end

  describe Principal do
    describe "initialization" do
      it "accepts :subject_class" do
        principal = Principal.new(:subject_class => Hash)
        principal.subject_class.should == Hash
        principal.subject_type.should  == 'Hash'
      end

      describe ":subject_class over :subject_type" do
        let(:properties) do
          props = ActiveSupport::OrderedHash.new
          props[:subject_class] = Hash
          props[:subject_type]  = 'String'
          props
        end

        let(:reversed_properties) do
          props = ActiveSupport::OrderedHash.new
          props[:subject_type]  = 'String'
          props[:subject_class] = Hash
          props
        end

        describe "when :subject_class is set before :subject_type" do
          it "prefers :subject_class" do
            principal = Principal.new(properties)
            principal.subject_class.should == Hash
            principal.subject_type.should  == 'Hash'
          end
        end

        describe "when :subject_class is set after :subject_type" do
          it "prefers :subject_class" do
            principal = Principal.new(reversed_properties)
            principal.subject_class.should == Hash
            principal.subject_type.should  == 'Hash'
          end
        end
      end
    end

    describe ".for_subject" do
      let(:subject_class) do
        Class.new { def self.name; 'Foo'; end; def id; 123; end }
      end
      let(:subject)       { subject_class.new }

      context "when a corresponding principal exists" do
        let!(:principal) do
          Principal.store(:subject_class => subject_class,
                          :subject_id    => subject.id)
        end

        it "returns the existing principal" do
          returned_principal = Principal.for_subject(subject)
          returned_principal.should == principal
        end
      end

      context "when a corresponding principal doesn't exist" do
        it "returns a new Principal with the correct properties set" do
          principal = Principal.for_subject(subject)
          principal.subject_id.should == 123
          principal.subject_class.should == subject_class
        end
      end
    end

    describe "the subject's class" do
      it "is, by default, deduced from the subject_type string" do
        principal = Principal.new(:subject_type => "Hash")
        principal.subject_class.should == Hash
      end

      it "can be set using an accessor" do
        principal = Principal.new(:subject_type => "Hash")
        principal.subject_class = String

        principal.subject_class.should == String
      end

      it "sets the subject_type accordingly" do
        principal = Principal.new(:subject_type => "Hash")
        principal.subject_class = String

        principal.subject_type.should == "String"
      end
    end

    describe "on #destroy" do
      let(:persistent) { stub('persistent', :destroy => nil) }
      let(:principal) { Principal.wrap(persistent) }

      before do
        Role.stub(:unassign_all_from).with(principal)
      end

      it "destroys all role assignments associated when it is destroyed" do
        Role.should_receive(:unassign_all_from).with(principal)
        principal.destroy
      end

      it "does so by disabling assignment restriction" do
        Role.should_receive_without_assignment_restriction(:unassign_all_from) do
          principal.destroy
        end
      end

      it "calls #destroy on the 'persistent'" do
        persistent.should_receive(:destroy)
        principal.destroy
      end

      it "does so after unassigning roles" do
        Role.stub(:unassign_all_from) do
          persistent.already_unassigned_roles
        end
        persistent.should_receive(:already_unassigned_roles).ordered
        persistent.should_receive(:destroy).ordered

        principal.destroy
      end
    end

    describe "#subject" do
      let(:model) { Class.new }
      let(:principal) { Principal.new(:subject_class => model,
                                      :subject_id    => 1000) }
      def build_subject
        # Strings compare char by char, but each time object_id changes.
        'subject'
      end

      before do
        model.stub(:unrestricted_find) do |id|
          if id == principal.subject_id
            build_subject()
          else
            fail
          end
        end
      end

      it "gets the record by calling .unrestricted_find in the model" do
        subject = build_subject
        principal.subject.should == subject
      end

      it "is cached" do
        prev_subject = principal.subject
        next_subject = principal.subject

        next_subject.should be prev_subject
      end
    end

    describe ".clear_anonymous_cache" do
      it "clears the anonymous principal cache" do
        prev_principal = Principal.anonymous
        Principal.clear_anonymous_cache
        next_principal = Principal.anonymous

        next_principal.should_not be prev_principal
      end
    end

    describe ".anonymous" do
      it "is a principal" do
        Principal.anonymous.should be_a(Principal)
      end

      describe "the principal returned" do
        it "has subject_id == AccessControl::AnonymousUser.instance.id" do
          Principal.anonymous.subject_id.should ==
            AccessControl::AnonymousUser.instance.id
        end

        it "has subject_type == AccessControl::AnonymousUser" do
          Principal.anonymous.subject_type.should ==
            AccessControl::AnonymousUser.name
        end

        it "is cached" do
          prev_node = Principal.anonymous
          next_node = Principal.anonymous

          next_node.should be prev_node
        end
      end

      specify "its #subject is the AnonymousUser" do
        Principal.anonymous.subject.should \
          be AccessControl::AnonymousUser.instance
      end
    end

    describe ".anonymous!" do
      describe "the principal returned" do
        before do
          Principal.clear_anonymous_cache
          Principal.anonymous
        end

        it "has subject_id == AccessControl::AnonymousUser.instance.id" do
          Principal.anonymous!.subject_id.should ==
            AccessControl::AnonymousUser.instance.id
        end

        it "has subject_type == AccessControl::AnonymousUser" do
          Principal.anonymous!.subject_type.should ==
            AccessControl::AnonymousUser.name
        end

        it "is not cached" do
          prev_principal = Principal.anonymous!
          next_principal = Principal.anonymous!

          next_principal.should_not be prev_principal
        end

        it "updates the cache" do
          prev_principal = Principal.anonymous!
          next_principal = Principal.anonymous

          next_principal.should be prev_principal
        end
      end

      it "raises an exception if the global node wasn't created yet" do
        Principal::Persistent.destroy_all

        lambda {
          Principal.anonymous!
        }.should raise_exception(AccessControl::NoAnonymousPrincipal)
      end
    end

    describe "#anonymous?" do
      let(:principal) { Principal.new }
      let(:anon_id) { 1 }
      before { AccessControl.stub(:anonymous_id).and_return(anon_id) }

      subject { principal }

      context "the principal has the same id of the global principal" do
        before { principal.stub(:id).and_return(anon_id) }
        it { should be_anonymous }
      end

      context "the principal has any other id" do
        before { principal.stub(:id).and_return('any other id') }
        it { should_not be_anonymous }
      end
    end

    describe "unrestrictable principal" do
      describe "ID" do
        subject { UnrestrictablePrincipal::ID }
        it { should be_a(Fixnum) }
      end

      describe "instance's id" do
        subject { UnrestrictablePrincipal.instance.id }
        it { should == UnrestrictablePrincipal::ID }
      end
    end

    describe "unrestrictable user" do
      describe "#ac_principal" do
        it "returns the principal" do
          UnrestrictableUser.instance.ac_principal.
            should == UnrestrictablePrincipal.instance
        end
      end
    end
  end
end
