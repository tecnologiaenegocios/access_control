require 'spec_helper'
require 'access_control/grantable'

module AccessControl
  describe Grantable do

    let(:orm_class)     { Class.new }
    let(:grantable)     { Grantable.new(orm_class) }
    let(:principal_ids) { stub('principal ids') }
    let(:permissions)   { stub('permissions') }
    let(:node1)         { stub('node1', :securable_id => 0) }
    let(:node2)         { stub('node2', :securable_id => 13238) }
    let(:manager)       { mock('manager', :principal_ids => principal_ids) }

    before do
      orm_class.stub(:name).and_return('Record')
      AccessControl.stub(:manager).and_return(manager)
    end

    it "can be created with an orm class" do
      Grantable.new(orm_class)
    end

    describe "#ids_with" do

      let(:scoped) do
        stub('scoped', :select_values_of_column => [
          node1.securable_id, node2.securable_id
        ])
      end

      before do
        Node.stub(:granted_for).and_return(scoped)
      end

      it "gets the current principal ids" do
        manager.should_receive(:principal_ids).and_return(principal_ids)
        grantable.ids_with(permissions)
      end

      it "finds all nodes grantable for the current principals" do
        Node.should_receive(:granted_for).
          with('Record', principal_ids, permissions).
          and_return(scoped)
        grantable.ids_with(permissions)
      end

      it "gets the securable ids from the nodes" do
        scoped.should_receive(:select_values_of_column).with(:securable_id).
          and_return([])
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
        Node.stub(:granted_for).and_return([node1, node2])
      end

      it "gets the current principal ids" do
        manager.should_receive(:principal_ids).and_return(principal_ids)
        grantable.from_class?(permissions)
      end

      it "finds nodes grantable for the current principals for securable 0" do
        Node.should_receive(:granted_for).
          with('Record', principal_ids, permissions).
          and_return([])
        grantable.from_class?(permissions)
      end

      context "when one or more nodes are returned" do
        context "and one of them has securable_id == 0" do
          it "returns true" do
            grantable.from_class?(permissions).should be_true
          end
        end
        context "and none of them have securable_id == 0" do
          it "returns false" do
            Node.stub(:granted_for).and_return([node2])
            grantable.from_class?(permissions).should be_false
          end
        end
      end

      context "when nothing is returned" do
        it "returns false" do
          Node.stub(:granted_for).and_return([])
          grantable.from_class?(permissions).should be_false
        end
      end

    end

  end
end
