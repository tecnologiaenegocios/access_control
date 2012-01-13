require 'spec_helper'
require 'access_control/behavior'
require 'access_control/configuration'
require 'access_control/node'

module AccessControl
  describe ".Node" do
    specify "when the argument is a Node, returns it untouched" do
      node = Node.new
      return_value = AccessControl.Node(node)

      return_value.should be node
    end

    specify "when the argument responds to .ac_node, its return value "\
            "is returned" do
      node = Node.new
      securable = stub("Securable", :ac_node => node)

      return_value = AccessControl.Node(securable)
      return_value.should be node
    end

    specify "when the argument is a GlobalRecord, returns the global node" do
      global_node = stub
      AccessControl.stub(:global_node).and_return(global_node)

      return_value = AccessControl.Node(GlobalRecord.instance)
      return_value.should be global_node
    end

    specify "launches Exception for non-recognized argument types" do
      random_object = stub.as_null_object

      lambda {
        AccessControl::Node(random_object)
      }.should raise_error(AccessControl::UnrecognizedSecurable)
    end
  end

  describe Node do
    describe "initialization" do
      it "accepts :securable_class" do
        node = Node.new(:securable_class => Hash)
        node.securable_class.should == Hash
        node.securable_type.should  == 'Hash'
      end

      describe ":securable_class over :securable_type" do
        let(:properties) do
          props = ActiveSupport::OrderedHash.new
          props[:securable_class] = Hash
          props[:securable_type]  = 'String'
          props
        end

        let(:reversed_properties) do
          props = ActiveSupport::OrderedHash.new
          props[:securable_type]  = 'String'
          props[:securable_class] = Hash
          props
        end

        describe "when :securable_class is set before :securable_type" do
          it "prefers :securable_class" do
            node = Node.new(properties)
            node.securable_class.should == Hash
            node.securable_type.should  == 'Hash'
          end
        end

        describe "when :securable_class is set after :securable_type" do
          it "prefers :securable_class" do
            node = Node.new(reversed_properties)
            node.securable_class.should == Hash
            node.securable_type.should  == 'Hash'
          end
        end
      end
    end

    describe ".for_securable" do
      let(:securable_class) { FakeSecurable }
      let(:securable)       { securable_class.new }

      context "when a corresponding node exists" do
        let!(:node) do
          Node.store(:securable_class => securable_class,
                     :securable_id    => securable.id)
        end

        it "returns the existing node" do
          returned_node = Node.for_securable(securable)
          returned_node.should == node
        end
      end

      context "when a corresponding node doesn't exist" do
        it "returns a new Node with the correct properties set" do
          node = Node.for_securable(securable)
          node.securable_id.should    == securable.id
          node.securable_class.should == securable.class
        end
      end
    end

    describe ".clear_global_cache" do
      it "clears the global node cache" do
        prev_node = Node.global
        Node.clear_global_cache
        next_node = Node.global

        next_node.should_not be prev_node
      end
    end

    describe ".global" do

      it "is a node" do
        Node.global.should be_a(AccessControl::Node)
      end

      describe "the node returned" do
        it "has securable_id == AccessControl::GlobalRecord.instance.id" do
          Node.global.securable_id.should ==
            AccessControl::GlobalRecord.instance.id
        end

        it "has securable_type == AccessControl::GlobalRecord" do
          Node.global.securable_type.should ==
            AccessControl::GlobalRecord.name
        end

        it "is cached" do
          prev_node = Node.global
          next_node = Node.global

          next_node.should be prev_node
        end
      end

      specify "its #securable is the GlobalRecord" do
        Node.global.securable.should be AccessControl::GlobalRecord.instance
      end
    end

    describe ".global!" do
      describe "the node returned" do
        before do
          Node.clear_global_cache
          Node.global
        end

        it "has securable_id == AccessControl::GlobalRecord.instance.id" do
          Node.global!.securable_id.should ==
            AccessControl::GlobalRecord.instance.id
        end

        it "has securable_type == AccessControl::GlobalRecord" do
          Node.global!.securable_type.should ==
            AccessControl::GlobalRecord.name
        end

        it "is not cached" do
          prev_node = Node.global!
          next_node = Node.global!

          next_node.should_not be prev_node
        end

        it "updates the cache" do
          prev_node = Node.global!
          next_node = Node.global

          next_node.should be prev_node
        end
      end

      it "raises an exception if the global node wasn't created yet" do
        Node::Persistent.delete

        lambda {
          Node.global!
        }.should raise_exception(AccessControl::NoGlobalNode)
      end
    end

    describe "#global?" do
      let(:node) { Node.new }
      let(:global_id) { 1 }
      before { AccessControl.stub(:global_node_id).and_return(global_id) }

      subject { node }

      context "the node has the same id of the global node" do
        before { node.stub(:id).and_return(global_id) }
        it { should be_global }
      end

      context "the node has any other id" do
        before { node.stub(:id).and_return('any other id') }
        it { should_not be_global }
      end
    end

    describe "subset delegation" do
      it "delegates subset .with_type to the persistent model" do
        Node.delegated_subsets.should include(:with_type)
      end
    end

    describe "#securable" do

      let(:model) { Class.new }
      let(:node) { Node.new(:securable_class => model,
                            :securable_id    => 1000) }
      def build_securable
        # Strings compare char by char, but each time object_id changes.
        'securable'
      end

      before do
        model.stub(:unrestricted_find) do |id|
          if id == node.securable_id
            build_securable()
          else
            fail
          end
        end
      end

      it "gets the record by calling .unrestricted_find in the model" do
        securable = build_securable
        node.securable.should == securable
      end

      it "is cached" do
        prev_securable = node.securable
        next_securable = node.securable

        next_securable.should be prev_securable
      end
    end

    describe "the securable's class" do
      it "is, by default, deduced from the securable_type string" do
        node = Node.new(:securable_type => "Hash")
        node.securable_class.should == Hash
      end

      it "can be set using an accessor" do
        node = Node.new(:securable_type => "Hash")
        node.securable_class = String

        node.securable_class.should == String
      end

      it "sets the securable_type accordingly" do
        node = Node.new(:securable_type => "Hash")
        node.securable_class = String

        node.securable_type.should == "String"
      end
    end

    describe "blocking and unblocking" do
      let(:securable_class) do
        FakeSecurableClass.new(:parents) do
          include Inheritance
          inherits_permissions_from :parents
          def self.permissions_required_to_create
            Set.new
          end
          def self.permissions_required_to_destroy
            Set.new
          end
        end
      end

      def build_securable(parents=[])
        securable_class.new(:parents => parents)
      end

      let(:inheritance_manager) { Node::InheritanceManager.new(subject) }

      let(:parent) do
        securable = build_securable
        parent = Node.store(:securable_class => securable.class,
                            :securable_id    => securable.id)
        securable.ac_node = parent
        parent
      end

      subject do
        securable = build_securable([parent.securable])
        Node.store(:securable_class => securable.class,
                   :securable_id    => securable.id)
      end

      specify "a new node is always unblocked" do
        Node.new.should_not be_blocked
      end

      specify "the global node is unblocked" do
        AccessControl.global_node.should_not be_blocked
      end

      describe "blocking a node" do
        it { subject.block = true; should be_blocked }

        it "removes all parents" do
          subject.block = true
          inheritance_manager.parents.should be_empty
        end

        it "causes no error if blocking twice" do
          subject.block = true
          subject.block = true
          inheritance_manager.parents.should be_empty
        end

        context "with unsaved securable parents" do
          it "causes no error" do
            parent.stub(:persisted?).and_return(false)
            subject.block = true
            inheritance_manager.parents.should be_empty
          end
        end
      end

      describe "unblocking a node" do
        before { subject.block = true }
        it { subject.block = false; should_not be_blocked }

        it "re-adds previous parents, according to the securable class" do
          subject.block = false
          inheritance_manager.parents.should include_only(parent)
        end

        it "causes no error if unblocking twice" do
          subject.block = false
          subject.block = false
          inheritance_manager.parents.should include_only(parent)
        end

        context "with unsaved securable parents" do
          it "doesn't add the unsaved parent" do
            parent.stub(:persisted?).and_return(false)
            subject.block = false
            inheritance_manager.parents.should be_empty
          end
        end
      end
    end

    context "creating and updating" do
      let(:node1)   { stub("Node 1", :id => 1, :persisted? => true) }
      let(:node2)   { stub("Node 2", :id => 2, :persisted? => true) }
      let(:node3)   { stub("Node 3", :id => 3, :persisted? => true) }
      let(:node4)   { stub("Node 4", :id => 4, :persisted? => true) }

      let(:parent1) { stub("Parent 1", :ac_node => node1) }
      let(:parent2) { stub("Parent 2", :ac_node => node2) }
      let(:parent3) { stub("Parent 3", :ac_node => node3) }
      let(:parent4) { stub("Parent 4", :ac_node => node4) }

      let(:securable_class) do
        FakeSecurableClass.new(:parent1, :parent2, :parent3, :parent4) do
          include Inheritance
          inherits_permissions_from :parent1, :parent2, :parent3, :parent4
        end
      end

      let(:securable) { securable_class.new(:parent1 => parent1,
                                            :parent2 => parent2,
                                            :parent3 => nil,
                                            :parent4 => [parent4]) }

      let(:inheritance_manager) { stub("Inheritance Manager") }

      before do
        subject.inheritance_manager = inheritance_manager
        inheritance_manager.stub(:parents => [])
        inheritance_manager.stub(:add_parent)
      end

      subject { Node.new(:securable_class => securable_class,
                        :securable_id    => securable.id) }

      it "returns false if not saved persistent node successfully" do
        persistent = subject.persistent
        persistent.stub(:save).and_return(false)

        subject.persist.should be_false
      end

      it "returns true if saved persistent node successfully" do
        persistent = subject.persistent
        persistent.stub(:save).and_return(true)

        subject.persist.should be_true
      end

      context "when saved successfully" do
        before { subject.persistent.stub(:save).and_return(true) }

        context "when the node is a new record" do
          it "uses inheritance manager to add the nodes of the parent securables" do
            inheritance_manager.should_receive(:add_parent).with(node1)
            inheritance_manager.should_receive(:add_parent).with(node2)
            inheritance_manager.should_receive(:add_parent).with(node4)

            subject.persist
          end

          it "doesn't try to add non-persisted parent nodes" do
            node2.stub(:persisted? => false)
            inheritance_manager.should_not_receive(:add_parent).with(node2)

            subject.persist
          end
        end

        context "when the node was already saved" do
          before do
            subject.persist
          end

          context "and later parents are added to securable" do
            before do
              securable.parent3 = parent3
            end

            it "adds the new parents using the inheritance manager" do
              inheritance_manager.stub(:parents => [node1, node2, node4])
              inheritance_manager.should_receive(:add_parent).with(node3)

              subject.persist
            end

            it "doesn't remove it" do
              # Seems silly spec this, but previously there was a bug that
              # new parents added were actually removed when checking for
              # securable parents which were removed.
              parents = [node1, node2, node4]
              inheritance_manager.stub(:add_parent) do |parent|
                parents << parent
              end
              inheritance_manager.stub(:parents).and_return(parents)
              inheritance_manager.should_not_receive(:del_parent)

              subject.persist
            end
          end

          context "and later parents are removed" do
            before do
              securable.parent2 = nil
            end

            it "deletes the old parents using the inheritance manager" do
              inheritance_manager.stub(:parents => [node1, node2, node4])
              inheritance_manager.should_receive(:del_parent).with(node2)

              subject.persist
            end
          end
        end
      end

      context "when not saved successfully" do
        before { subject.persistent.stub(:save).and_return(false) }

        it "doesn't try to add any parent" do
          inheritance_manager.should_not_receive(:add_parent)

          subject.persist
        end

        it "doesn't try to delete any parent" do
          inheritance_manager.should_not_receive(:del_parent)

          subject.persist
        end
      end
    end

    describe "on #destroy" do
      let(:persistent) { Node::Persistent.new }
      let(:node)       { Node.wrap(persistent) }

      before do
        Role.stub(:unassign_all_at).with(node)
        persistent.stub(:destroy)
      end

      it "destroys all role assignments associated when it is destroyed" do
        Role.should_receive(:unassign_all_at).with(node)
        node.destroy
      end

      it "calls #destroy on the 'persistent'" do
        persistent.should_receive(:destroy)
        node.destroy
      end

      it "does so after unassigning roles" do
        Role.stub(:unassign_all_at) do
          persistent.already_unassigned_roles
        end
        persistent.should_receive(:already_unassigned_roles).ordered
        persistent.should_receive(:destroy).ordered

        node.destroy
      end

      describe "Removal of children and parents" do
        let(:inheritance_manager) { mock("Inheritance Manager") }

        before do
          inheritance_manager.stub(:del_all_parents_with_checks)
          inheritance_manager.stub(:del_all_children)
          node.inheritance_manager = inheritance_manager
        end

        it "asks the inheritance manager to unassign it from all parents" do
          inheritance_manager.should_receive(:del_all_parents_with_checks)
          node.destroy
        end

        it "asks the inheritance manager to unassign all its children" do
          inheritance_manager.should_receive(:del_all_children)
          node.destroy
        end
      end
    end
  end
end
