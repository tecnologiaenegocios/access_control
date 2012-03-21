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

    specify "when the argument is a UnrestrictablePrincipal, just returns it" do
      principal = AccessControl::UnrestrictablePrincipal.instance
      return_value = AccessControl::Principal(principal)

      return_value.should equal principal
    end

    specify "when the argument is an AnonymousUser, returns the anonymous "\
            "principal" do
      anonymous_principal = stub
      AccessControl.stub(:anonymous).and_return(anonymous_principal)

      return_value = AccessControl.Principal(AnonymousUser.instance)
      return_value.should be anonymous_principal
    end

    it "launches Exception for non-recognized arguments" do
      random_object = stub.as_null_object

      lambda {
        AccessControl.Principal(random_object)
      }.should raise_exception(AccessControl::UnrecognizedSubject)
    end
  end

  describe Principal do
    after { Principal.clear_anonymous_cache }

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
      let(:subject)    { subject_class.new }
      let(:subject_id) { subject.id }
      let(:orm)        { stub }

      before do
        ORM.stub(:adapt_class).with(subject_class).and_return(orm)
        orm.stub(:pk_of).with(subject).and_return(subject_id)
      end

      context "when the record is already persisted" do
        before { orm.stub(:persisted?).with(subject).and_return(true) }

        context "when a corresponding principal exists" do
          let!(:principal) do
            Principal.store(:subject_class => subject_class,
                            :subject_id    => subject_id)
          end

          it "returns the existing principal" do
            returned_principal = Principal.for_subject(subject)
            returned_principal.should == principal
          end

          it "uses the id returned by the ORM adapter" do
            subject.stub(:id).and_return(subject_id + 1000)
            principal = Principal.for_subject(subject)
            principal.subject_id.should == subject_id
          end

          it "sets the subject to avoid unnecessary trips to the DB" do
            principal = Principal.for_subject(subject)
            principal.subject.should == subject
          end
        end

        context "when a corresponding principal doesn't exist" do
          it "returns a new Principal with the correct properties set" do
            principal = Principal.for_subject(subject)
            principal.subject_id.should == 123
            principal.subject_class.should == subject_class
          end

          it "sets the subject to avoid unnecessary trips to the DB" do
            principal = Principal.for_subject(subject)
            principal.subject.should == subject
          end

          it "uses the id returned by the ORM adapter" do
            subject.stub(:id).and_return(subject_id + 1000)
            principal = Principal.for_subject(subject)
            principal.subject_id.should == subject_id
          end

          it "doesn't persist the principal" do
            principal = Principal.for_subject(subject)
            principal.should_not be_persisted
          end
        end
      end

      context "when the record is not yet persisted" do
        before { orm.stub(:persisted?).with(subject).and_return(false) }

        it "returns a new Principal" do
          principal = Principal.for_subject(subject)
          principal.should_not be_persisted
        end

        it "doesn't set the subject id" do
          principal = Principal.for_subject(subject)
          principal.subject_id.should be_nil
        end

        it "doesn't persist the principal" do
          principal = Principal.for_subject(subject)
          principal.should_not be_persisted
        end

        it "sets the subject class of the new Principal" do
          principal = Principal.for_subject(subject)
          principal.subject_class.should == subject_class
        end

        it "sets the subject to avoid unnecessary trips to the DB" do
          principal = Principal.for_subject(subject)
          principal.subject.should == subject
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
      let(:model)     { Class.new }
      let(:principal) { Principal.new(:subject_class => model,
                                      :subject_id    => subject_id) }

      let(:adapted)    { stub }
      let(:manager)    { stub }
      let(:subject_id) { 1000 }

      def build_subject
        # Strings compare char by char, but each time object_id changes.
        'subject'
      end

      before do
        ORM.stub(:adapt_class).with(model).and_return(adapted)
        AccessControl.stub(:manager).and_return(manager)

        manager.define_singleton_method(:without_query_restriction) do |&b|
          b.call
        end

        adapted.stub(:[]) do |id|
          if id == subject_id
            build_subject()
          else
            nil
          end
        end
      end

      it "gets the record by calling .[] in the adapted model" do
        subject = build_subject
        principal.subject.should == subject
      end

      it "raises error if record is not found" do
        principal.stub(:subject_id).and_return('another id')
        lambda { principal.subject }.should raise_exception(NotFoundError)
      end

      it "gets the record in an unrestricted way" do
        adapted.should_receive_without_query_restriction(:[]) do
          principal.subject
        end
      end

      it "is cached" do
        prev_subject = principal.subject
        next_subject = principal.subject

        next_subject.should be prev_subject
      end

      it "can be changed by using the setter" do
        principal.subject = 'some other subject'
        principal.subject.should == 'some other subject'
      end

      specify "#subject= does NOT change subject_type" do
        model.stub(:name).and_return('Foo')
        principal.subject = stub(:subject_type => 'Bar')
        principal.subject_type.should == 'Foo'
      end

      specify "#subject= does NOT change subject_id" do
        principal.subject = stub(:subject_id => subject_id * 2)
        principal.subject_id.should == subject_id
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
        Principal::Persistent.delete

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

    describe ".normalize_collection" do
      let(:principal) { Principal.new }

      context "when given a single Principal instance" do
        it "returns a singleton collection containing the principal untoucheD" do
          return_value = Principal.normalize_collection(principal)
          return_value.should include_only(principal)
        end
      end

      context "when given a single subject instance" do
        it "returns a singleton collection with the subject's principal" do
          subject = stub(:ac_principal => principal)
          return_value = Principal.normalize_collection(subject)
          return_value.should include_only(principal)
        end
      end

      context "when given a collection of Principal instances" do
        it "returns a collection with the instances" do
          other_principal = Principal.new
          principals      = [principal, other_principal]

          return_value = Principal.normalize_collection(principals)
          return_value.should include_only(*principals)
        end
      end

      context "when given a collection of subject instances" do
        it "returns a collection with the instances" do
          other_principal  = Principal.new
          subjects  = [stub(:ac_principal => principal),
                       stub(:ac_principal => other_principal)]

          return_value = Principal.normalize_collection(subjects)
          return_value.should include_only(principal, other_principal)
        end
      end
    end
  end
end
