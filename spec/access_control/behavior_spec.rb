require 'spec_helper'
require 'access_control/behavior'
require 'access_control/node'
require 'access_control/securable'

describe AccessControl do

  after do
    # Clear the instantiated manager.
    AccessControl.no_manager
  end

  describe ".manager" do

    it "returns a Manager" do
      AccessControl.manager.should be_a(AccessControl::Manager)
    end

    it "instantiates the manager only once" do
      first = AccessControl.manager
      second = AccessControl.manager
      first.should equal(second)
    end

    it "stores the manager in the current thread" do
      current_manager = AccessControl.manager
      thr_manager = nil
      Thread.new { thr_manager = AccessControl.manager }
      current_manager.should_not equal(thr_manager)
    end

  end

  describe ".global_node_id" do
    it "returns the global node's id" do
      global = stub(:id => "The global node ID")
      AccessControl::Node.stub(:global => global)

      AccessControl.global_node_id.should == "The global node ID"
    end
  end

  describe ".global_securable_type" do
    subject { AccessControl.global_securable_type }
    it { should == AccessControl::GlobalRecord.name }
  end

  describe ".global_securable_id" do
    subject { AccessControl.global_securable_id }
    it { should == AccessControl::GlobalRecord.instance.id }
  end

  describe ".global_node" do
    it "returns the global node" do
      global = stub
      AccessControl::Node.stub(:global => global)

      AccessControl.global_node.should == global
    end
  end

  describe ".anonymous_id" do
    it "returns the anonymous's id" do
      anonymous = stub(:id => "The anonymous ID")
      AccessControl::Principal.stub(:anonymous => anonymous)

      AccessControl.anonymous_id.should == "The anonymous ID"
    end
  end

  describe ".anonymous_subject_type" do
    subject { AccessControl.anonymous_subject_type }
    it { should == AccessControl::AnonymousUser.name }
  end

  describe ".anonymous_subject_id" do
    subject { AccessControl.anonymous_subject_id }
    it { should == AccessControl::AnonymousUser.instance.id }
  end

  describe ".anonymous" do
    it "returns the anonymous user" do
      anonymous = stub
      AccessControl::Principal.stub(:anonymous => anonymous)

      AccessControl.anonymous.should == anonymous
    end
  end

  describe AccessControl::GlobalRecord do

    subject { AccessControl::GlobalRecord.instance }

    it "cannot be instantiated" do
      lambda { AccessControl::GlobalRecord.new }.should raise_exception
    end

    it "has id == 1" do
      # The is is 1 and not 0 because we're using 0 for class nodes.
      subject.id.should == 1
    end

    it { should be_a AccessControl::Securable }

    describe ".unrestricted_find" do
      let(:global_record) { AccessControl::GlobalRecord.instance }
      subject { AccessControl::GlobalRecord.public_method(:unrestricted_find) }

      it "returns the global record when passed the :first parameter" do
        subject[:first].should == global_record
      end

      it "returns the global record when passed the :last parameter" do
        subject[:last].should == global_record
      end

      it "returns the global record when passed the GlobalRecord's ID" do
        subject[global_record.id].should == global_record
      end

      it "returns nil when passed a number that is not the GlobalRecord's ID" do
        subject[666].should be_nil
      end

      it "returns the global record inside a Set when passed :all" do
        subject[:all].should == Set[global_record]
      end
    end
  end

  describe AccessControl::AnonymousUser do
    subject { AccessControl::AnonymousUser.instance }

    it "cannot be instantiated" do
      lambda { AccessControl::AnonymousUser.new }.should raise_exception
    end

    it "has id == 1" do
      # The is is 1 and not 0 because we're using 0 for class nodes.
      subject.id.should == 1
    end

    describe ".unrestricted_find" do
      let(:anonymous_user) { AccessControl::AnonymousUser.instance }
      subject { AccessControl::AnonymousUser.public_method(:unrestricted_find) }

      it "returns the anonymous user when passed the :first parameter" do
        subject[:first].should == anonymous_user
      end

      it "returns the anonymous user when passed the :last parameter" do
        subject[:last].should == anonymous_user
      end

      it "returns the anonymous user when passed the AnonymousUser's ID" do
        subject[anonymous_user.id].should == anonymous_user
      end

      it "returns nil if passed a number that is not the AnonymousUser's ID" do
        subject[666].should be_nil
      end

      it "returns the anonymous user inside a Set when passed :all" do
        subject[:all].should == Set[anonymous_user]
      end
    end
  end

end
