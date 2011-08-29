require 'spec_helper'
require 'access_control/grantable'

module AccessControl
  describe Grantable do

    let(:model)         { Class.new }
    let(:grantable)     { Grantable.new(model) }
    let(:principal_ids) { stub('principal ids') }
    let(:permissions)   { stub('permissions') }
    let(:node1)         { stub('node1', :securable_id => 0) }
    let(:node2)         { stub('node2', :securable_id => 13238) }
    let(:manager)       { mock('manager', :principal_ids => principal_ids) }

    before do
      model.stub(:name).and_return('Record')
      AccessControl.stub(:manager).and_return(manager)
    end

    it "can be created with a model" do
      Grantable.new(model)
    end

    describe "#ids_with" do

      before do
        Node.stub(:granted_for).and_return([node1, node2])
      end

      it "gets the current principal ids" do
        manager.should_receive(:principal_ids).and_return(principal_ids)
        grantable.ids_with(permissions)
      end

      it "finds all nodes grantable for the current principals" do
        Node.should_receive(:granted_for).
          with('Record', principal_ids, permissions).
          and_return([node1, node2])
        grantable.ids_with(permissions)
      end

      it "returns the securable ids of the nodes" do
        grantable.ids_with(permissions).should include(13238)
      end

      it "excludes the zero node (the class node)" do
        grantable.ids_with(permissions).size.should == 1
      end

      it "returns a Set" do
        # This makes sense since order doesn't matter.  Also, we can't mix
        # arrays with sets in many operations, so when sensible (the order
        # doesn't matter) return a set.
        grantable.ids_with(permissions).should be_a(Set)
      end

    end

    describe "#from_class?" do

      before do
        Node.stub(:granted_for).and_return([node1])
      end

      it "gets the current principal ids" do
        manager.should_receive(:principal_ids).and_return(principal_ids)
        grantable.from_class?(permissions)
      end

      it "finds nodes grantable for the current principals for securable 0" do
        Node.should_receive(:granted_for).
          with('Record', principal_ids, permissions, {:securable_id => 0}).
          and_return([node1])
        grantable.from_class?(permissions)
      end

      describe "when a node is returned" do
        it "returns true" do
          grantable.from_class?(permissions).should be_true
        end
      end

      describe "when nothing is returned" do
        it "returns false" do
          Node.stub(:granted_for).and_return([])
          grantable.from_class?(permissions).should be_false
        end
      end

    end

  end
end
