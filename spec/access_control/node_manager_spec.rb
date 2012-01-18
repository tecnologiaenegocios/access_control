require 'spec_helper'

module AccessControl
  describe NodeManager do
    let(:node) { stub }
    subject { NodeManager.new(node) }

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
      let(:node)    { stub('main node') }

      let(:node1)   { stub("Node 1", :id => 1, :persisted? => true) }
      let(:node2)   { stub("Node 2", :id => 2, :persisted? => true) }
      let(:node3)   { stub("Node 3", :id => 3, :persisted? => true) }

      let(:parent1) { stub("Parent 1", :ac_node => node1) }
      let(:parent2) { stub("Parent 2", :ac_node => node2) }
      let(:parent3) { stub("Parent 3", :ac_node => node3) }

      let(:securable_class) do
        FakeSecurableClass.new(:parent1, :parent2, :parent3) do
          include Inheritance
          inherits_permissions_from :parent1, :parent2, :parent3
        end
      end

      let(:securable) { securable_class.new(:parent1 => parent1,
                                            :parent2 => nil,
                                            :parent3 => [parent3]) }

      let(:inheritance_manager) { stub("Inheritance Manager",
                                       :add_parent => nil,
                                       :del_parent => nil) }

      let(:role_propagation) { stub(:propagate! => nil, :depropagate! => nil) }
      let(:manager) { stub('manager', :can! => nil) }
      let(:create_permissions)  { stub('permissions enumerable (create)') }
      let(:destroy_permissions) { stub('permissions enumerable (destroy)') }

      before do
        Node::InheritanceManager.stub(:new).with(node).
          and_return(inheritance_manager)
        AccessControl.stub(:manager).and_return(manager)
        RolePropagation.stub(:new).and_return(role_propagation)
        securable_class.stub(
          :permissions_required_to_create  => create_permissions,
          :permissions_required_to_destroy => destroy_permissions
        )
        node.stub(:securable).and_return(securable)
        node.stub(:securable_class).and_return(securable_class)
      end

      subject { NodeManager.new(node) }

      context "when parents were added to node's securable" do
        before do
          securable.parent2 = parent2
          inheritance_manager.stub(:parents).and_return([node1, node3])
        end

        it "checks permission for adding the new parent" do
          manager.should_receive(:can!).with(create_permissions, node2)
          subject.refresh_parents
        end

        it "adds the new parents using the inheritance manager" do
          inheritance_manager.should_receive(:add_parent).with(node2)
          subject.refresh_parents
        end

        it "doesn't add it if it is not persisted" do
          node2.stub(:persisted?).and_return(false)
          inheritance_manager.should_not_receive(:add_parent).with(node2)
          subject.refresh_parents
        end

        it "propagates roles from the added parents" do
          role_propagation = stub
          RolePropagation.stub(:new).with(node, [node2]).
            and_return(role_propagation)
          role_propagation.should_receive(:propagate!)

          subject.refresh_parents
        end
      end

      context "when parents were removed" do
        before do
          securable.parent3 = []
          inheritance_manager.stub(:parents).and_return([node1, node3])
        end

        it "checks permissions for removing the parents" do
          manager.should_receive(:can!).with(destroy_permissions, node3)
          subject.refresh_parents
        end

        it "deletes the old parents using the inheritance manager" do
          inheritance_manager.should_receive(:del_parent).with(node3)

          subject.refresh_parents
        end

        it "doesn't delete it if it is not persisted" do
          node3.stub(:persisted?).and_return(false)
          inheritance_manager.should_not_receive(:del_parent).with(node2)
          subject.refresh_parents
        end

        it "depropagates roles from the removed parents" do
          role_propagation = stub
          RolePropagation.stub(:new).with(node, [node3]).
            and_return(role_propagation)
          role_propagation.should_receive(:depropagate!)

          subject.refresh_parents
        end
      end
    end

    describe "#disconnect" do
      let(:parent1) { stub }
      let(:parent2) { stub }
      let(:node)    { stub }
      let(:manager) { stub }

      let(:inheritance_manager) { stub }
      let(:role_propagation)    { stub }

      let(:destroy_permissions) { stub('permissions enumerable (destroy)') }
      let(:securable_class) do
        stub(:permissions_required_to_destroy => destroy_permissions)
      end

      subject { NodeManager.new(node) }

      before do
        Node::InheritanceManager.stub(:new).and_return(inheritance_manager)
        AccessControl.stub(:manager).and_return(manager)
        RolePropagation.stub(:new).and_return(role_propagation)
        role_propagation.stub(:depropagate!)
        inheritance_manager.stub(:del_all_parents)
        inheritance_manager.stub(:del_all_children)
        inheritance_manager.stub(:parents).and_return([parent1, parent2])
        manager.stub(:can!)
        node.stub(:securable_class).and_return(securable_class)
      end

      it "checks permissions for every parent" do
        manager.should_receive(:can!).with(destroy_permissions, parent1)
        manager.should_receive(:can!).with(destroy_permissions, parent2)

        subject.disconnect
      end

      it "depropagates roles from all of the parents" do
        role_propagation = stub

        # Any of the combinations below are acceptable.
        RolePropagation.stub(:new).with(node, [parent1, parent2]).
          and_return(role_propagation)
        RolePropagation.stub(:new).with(node, [parent2, parent1]).
          and_return(role_propagation)

        role_propagation.should_receive(:depropagate!)

        subject.disconnect
      end

      it "disconnects from all of the parents" do
        inheritance_manager.should_receive(:del_all_parents)
        subject.disconnect
      end

      it "disconnects from parents after checking permissions" do
        checked = {}
        manager.stub(:can!) do |permissions, parent_node|
          checked[parent_node] = true
        end
        inheritance_manager.stub(:del_all_parents) do
          inheritance_manager.parents.each do |parent_node|
            checked[parent_node].should be_true
          end
        end

        subject.disconnect
      end

      it "disconnects from parents after depropagation" do
        role_propagation.stub(:depropagate!) do
          inheritance_manager.already_depropagated
        end
        inheritance_manager.should_receive(:already_depropagated).ordered
        inheritance_manager.should_receive(:del_all_parents).ordered

        subject.disconnect
      end

      it "disconnects from all of the children" do
        inheritance_manager.should_receive(:del_all_children)
        subject.disconnect
      end

      it "disconnects after checking permissions" do
        checked = {}
        manager.stub(:can!) do |permissions, parent_node|
          checked[parent_node] = true
        end
        inheritance_manager.stub(:del_all_children) do
          inheritance_manager.parents.each do |parent_node|
            checked[parent_node].should be_true
          end
        end
        subject.disconnect
      end
    end

    describe "#block" do
      let(:node) { stub }
      let(:parent1) { stub }
      let(:inheritance_manager) { stub }
      let(:role_propagation) { stub }
      subject { NodeManager.new(node) }

      before do
        Node::InheritanceManager.stub(:new).and_return(inheritance_manager)
        RolePropagation.stub(:new).and_return(role_propagation)
        role_propagation.stub(:depropagate!)
        inheritance_manager.stub(:parents).and_return([parent1])
        inheritance_manager.stub(:del_all_parents)
      end

      it "depropagates roles from the blocked parents" do
        role_propagation = stub
        RolePropagation.stub(:new).with(node, [parent1]).
          and_return(role_propagation)
        role_propagation.should_receive(:depropagate!)

        subject.block
      end

      it "disconnects from all of the parents" do
        inheritance_manager.should_receive(:del_all_parents)
        subject.block
      end

      it "disconnects after depropagation" do
        role_propagation.stub(:depropagate!) do
          inheritance_manager.already_depropagated
        end
        inheritance_manager.should_receive(:already_depropagated).ordered
        inheritance_manager.should_receive(:del_all_parents).ordered

        subject.block
      end
    end

    describe "#unblock" do
      let(:node)    { stub('main node') }

      let(:node1)   { stub("Node 1", :id => 1, :persisted? => true) }
      let(:node2)   { stub("Node 2", :id => 2, :persisted? => false) }
      let(:node3)   { stub("Node 3", :id => 3, :persisted? => true) }

      let(:parent1) { stub("Parent 1", :ac_node => node1) }
      let(:parent2) { stub("Parent 2", :ac_node => node2) }
      let(:parent3) { stub("Parent 3", :ac_node => node3) }

      let(:securable_class) do
        FakeSecurableClass.new(:parent1, :parent2, :parent3, :parent4) do
          include Inheritance
          inherits_permissions_from :parent1, :parent2, :parent3, :parent4
        end
      end

      let(:securable) { securable_class.new(:parent1 => parent1,
                                            :parent2 => parent2,
                                            :parent3 => [parent3],
                                            :parent4 => nil) }

      let(:inheritance_manager) { stub("Inheritance Manager",
                                       :add_parent => nil,
                                       :del_parent => nil) }

      let(:role_propagation) { stub(:propagate! => nil, :depropagate! => nil) }

      before do
        Node::InheritanceManager.stub(:new).with(node).
          and_return(inheritance_manager)
        RolePropagation.stub(:new).and_return(role_propagation)
        node.stub(:securable).and_return(securable)
        node.stub(:securable_class).and_return(securable_class)
      end

      subject { NodeManager.new(node) }

      it "adds all parents which are already persisted from the securable" do
        inheritance_manager.should_receive(:add_parent).with(node1)
        inheritance_manager.should_receive(:add_parent).with(node3)

        subject.unblock
      end

      it "doesn't add nodes which aren't persisted" do
        inheritance_manager.should_not_receive(:add_parent).with(node2)
        subject.unblock
      end

      it "propagates roles from the re-added parents" do
        role_propagation = stub

        # Any of the combinations below are acceptable.
        RolePropagation.stub(:new).with(node, [node1, node3]).
          and_return(role_propagation)
        RolePropagation.stub(:new).with(node, [node3, node1]).
          and_return(role_propagation)

        role_propagation.should_receive(:propagate!)
        subject.unblock
      end
    end

    describe ".refresh_parents_of" do
      it "does the same as NodeManager.new(node).refresh_parents" do
        instance = stub
        node = stub
        instance.should_receive(:refresh_parents)
        NodeManager.stub(:new).with(node).and_return(instance)

        NodeManager.refresh_parents_of(node)
      end
    end

    describe ".disconnect" do
      it "does the same as NodeManager.new(node).disconnect" do
        instance = stub
        node = stub
        instance.should_receive(:disconnect)
        NodeManager.stub(:new).with(node).and_return(instance)

        NodeManager.disconnect(node)
      end
    end

    describe ".can_update!" do
      it "does the same as NodeManager.new(node).can_update!" do
        instance = stub
        node = stub
        instance.should_receive(:can_update!)
        NodeManager.stub(:new).with(node).and_return(instance)

        NodeManager.can_update!(node)
      end
    end

    describe ".block" do
      it "does the same as NodeManager.new(node).block" do
        instance = stub
        node = stub
        instance.should_receive(:block)
        NodeManager.stub(:new).with(node).and_return(instance)

        NodeManager.block(node)
      end
    end

    describe ".unblock" do
      it "does the same as NodeManager.new(node).unblock" do
        instance = stub
        node = stub
        instance.should_receive(:unblock)
        NodeManager.stub(:new).with(node).and_return(instance)

        NodeManager.unblock(node)
      end
    end
  end
end
