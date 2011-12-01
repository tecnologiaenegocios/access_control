require 'spec_helper'
require 'access_control/behavior'
require 'access_control/node'

describe AccessControl do

  after do
    # Clear the instantiated manager.
    AccessControl.no_manager
    # Clear global node cache.
    AccessControl.clear_global_node_cache
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

  describe ".global_node" do

    before { AccessControl.create_global_node! }

    it "is a node" do
      AccessControl.global_node.should be_a(AccessControl::Node)
    end

    it "is cached" do
      AccessControl.global_node
      AccessControl::Node.should_not_receive(:find)
      AccessControl.global_node
    end

    describe "node returned" do
      it "has securable_id == AccessControl::GlobalRecord.instance.id" do
        AccessControl.global_node.securable_id.should ==
          AccessControl::GlobalRecord.instance.id
      end
      it "has securable_type == AccessControl::GlobalRecord" do
        AccessControl.global_node.securable_type.should ==
          AccessControl::GlobalRecord.name
      end
    end

    describe "when there's no global node created" do
      it "raises exception" do
        AccessControl::Node.destroy_all
        lambda {
          AccessControl.global_node
        }.should raise_exception(AccessControl::NoGlobalNode)
      end
    end

  end

  describe ".global_node_id" do
    before { AccessControl.create_global_node! }
    it "returns the global id" do
      AccessControl.global_node_id.should == AccessControl::Node.first.id
    end
    it "is cached" do
      AccessControl.global_node_id
      AccessControl::Node.should_not_receive(:find)
      AccessControl.global_node_id
    end
  end

  describe AccessControl::GlobalRecord do

    it "cannot be instantiated" do
      lambda { AccessControl::GlobalRecord.new }.should raise_exception
    end

    it "has id == 1" do
      # The is is 1 and not 0 because we're using 0 for class nodes.
      AccessControl::GlobalRecord.instance.id.should == 1
    end

    describe "#ac_node" do
      it "returns the global node" do
        global_node = stub('the global node')
        AccessControl.stub(:global_node).and_return(global_node)
        AccessControl::GlobalRecord.instance.ac_node.should equal(global_node)
      end
    end

  end

end
