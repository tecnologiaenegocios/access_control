require 'spec_helper'

module AccessControl
  describe NodeManager do
    let(:node) { stub }
    subject { NodeManager.new(node) }

    describe "#assign_default_roles" do
      let(:principals) { stub('principals enumerable') }
      let(:default_roles) { stub('default roles enumerable') }

      before do
        Role.stub(:default).and_return(default_roles)
        AccessControl.stub_chain(:manager, :principals).and_return(principals)
      end

      it "assigns default roles to the current principals at the given node" do
        Role.should_receive(:assign_all).with(default_roles, principals, node)
        subject.assign_default_roles
      end
    end

    describe "#can_update!" do
      let(:securable_class) do
        stub('securable class',
             :permissions_required_to_update => update_permissions)
      end
      let(:update_permissions) { stub('permissions enumerable') }
      let(:manager)            { stub('manager') }

      before do
        node.stub(:securable_class).and_return(securable_class)
        AccessControl.stub(:manager).and_return(manager)
      end

      it "checks if the principals are granted with update permissions" do
        manager.should_receive(:can!).with(update_permissions, node)

        subject.can_update!
      end
    end

    describe "#refresh_parents" do
      it "tells the node to refresh its parents" do
        node.should_receive(:refresh_parents)

        subject.refresh_parents
      end
    end
  end
end
