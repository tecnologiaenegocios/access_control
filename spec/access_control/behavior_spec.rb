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

  describe ".global_node" do
    it "returns the global node" do
      global = stub
      AccessControl::Node.stub(:global => global)

      AccessControl.global_node.should == global
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

    describe "its node" do
      let(:global_node) { stub('the global node') }
      before { AccessControl.stub(:global_node).and_return(global_node) }

      it "is the global node" do
        subject.ac_node.should be global_node
      end

      it "is returned without problems from AccessControl.Node" do
        return_value = AccessControl::Node(subject)
        return_value.should be global_node
      end
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

end
