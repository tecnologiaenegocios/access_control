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

      return_value = AccessControl::Node(securable)
      return_value.should be node
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
          Node.store(:securable_class => securable.class,
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
        Node::Persistent.destroy_all

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

    describe "scope delegation" do
      it "delegates scope .with_type to the persistent model" do
        Node.delegated_scopes.should include(:with_type)
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

      it "does so by disabling assignment restriction" do
        Role.should_receive_without_assignment_restriction(:unassign_all_at) do
          node.destroy
        end
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

  describe "blocking and unblocking" do
    let(:manager) { stub("Manager") }
    let(:node) { Node.new }

    before do
      AccessControl.stub(:manager => manager)
    end

    it "defaults to unblocked (block == false)" do
      node.block.should be_false
    end

    describe "when blocking" do

      it "checks if the user has 'change_inheritance_blocking'" do
        manager.should_receive(:can!).
          with('change_inheritance_blocking', node)
        node.block = true
      end

    end

    describe "when unblocking" do

      it "checks if the user has 'change_inheritance_blocking'" do
        manager.should_receive(:can!).
          with('change_inheritance_blocking', node)
        node.block = false
      end

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

  describe "inheritance-related methods" do
    subject { Node.new(:inheritance_manager => inheritance_manager) }

    let(:inheritance_manager) { stub("Inheritance manager") }

    context "on blocked nodes" do
      before do
        subject.block = true
      end

      let(:global_node) { Node.global }

      describe "#ancestors" do
        it "returns itself and the global node" do
          subject.ancestors.should == Set[subject, global_node]
        end
      end

      describe "#strict_ancestors" do
        it "returns only the global node" do
          subject.strict_ancestors.should == Set[global_node]
        end
      end

      describe "#unblocked_ancestors" do
        it "returns itself and the global node" do
          subject.unblocked_ancestors.should == Set[subject, global_node]
        end
      end

      describe "#strict_unblocked_ancestors" do
        it "returns only the global node" do
          subject.strict_unblocked_ancestors.should == Set[global_node]
        end
      end

      describe "#parents" do
        it "returns an empty Set" do
          subject.parents.should == Set.new
        end
      end

      describe "#unblocked_parents" do
        it "returns an empty Set" do
          subject.unblocked_parents.should == Set.new
        end
      end
    end

    context "on non-blocked nodes" do
      before { subject.block = false }

      describe "#strict_ancestors" do
        it "returns the Set generated by inheritance_manager" do
          ancestors_set = Set[stub]
          inheritance_manager.stub(:ancestors => ancestors_set)

          subject.strict_ancestors.should == ancestors_set
        end
      end

      describe "#ancestors" do
        it "is Set generated by inheritance_manager, plus the node" do
          ancestor = stub
          inheritance_manager.stub(:ancestors => Set[ancestor])

          subject.ancestors.should == Set[ancestor, subject]
        end
      end

      describe "#strict_unblocked_ancestors" do
        let(:unblocked_ancestor) { stub("unblocked", :block => false) }
        let(:blocked_ancestor)   { stub("blocked",   :block => true) }

        before do
          inheritance_manager.stub(:filtered_ancestors) do |filter|
            ancestors = [blocked_ancestor, unblocked_ancestor]
            Set.new(ancestors.select(&filter))
          end
        end

        it "returns unblocked ancestors" do
          returned_set = subject.strict_unblocked_ancestors
          returned_set.should include(unblocked_ancestor)
        end

        it "doesn't return blocked ancestors" do
          returned_set = subject.strict_unblocked_ancestors
          returned_set.should_not include(blocked_ancestor)
        end

        it "doesn't add itself to the Set" do
          returned_set = subject.strict_unblocked_ancestors
          returned_set.should_not include(subject)
        end
      end

      describe "#unblocked_ancestors" do
        let(:blocked_ancestor)   { stub("blocked",   :block => true)  }
        let(:unblocked_ancestor) { stub("unblocked", :block => false) }

        before do
          inheritance_manager.stub(:filtered_ancestors) do |filter|
            ancestors = [blocked_ancestor, unblocked_ancestor]
            Set.new(ancestors.select(&filter))
          end
        end

        it "returns unblocked ancestors" do
          returned_set = subject.unblocked_ancestors
          returned_set.should include(unblocked_ancestor)
        end

        it "doesn't return blocked ancestors" do
          returned_set = subject.unblocked_ancestors
          returned_set.should_not include(blocked_ancestor)
        end

        it "adds itself to the Set" do
          returned_set = subject.unblocked_ancestors
          returned_set.should include(subject)
        end
      end

      describe "#parents" do
        let(:blocked_parent) { stub("blocked", :block => true) }
        let(:unblocked_parent) { stub("blocked", :unblock => true) }

        before do
          parents = Set[blocked_parent, unblocked_parent]
          inheritance_manager.stub(:parents => parents)
        end

        it "returns unblocked parents" do
          returned_set = subject.parents
          returned_set.should include unblocked_parent
        end

        it "returns blocked parents" do
          returned_set = subject.parents
          returned_set.should include blocked_parent
        end

        it "doesn't return itself" do
          returned_set = subject.parents
          returned_set.should_not include subject
        end
      end

      describe "#unblocked_parents" do
        let(:blocked_parent)   { stub("blocked",   :block => true)  }
        let(:unblocked_parent) { stub("unblocked", :block => false) }

        before do
          parents = Set[blocked_parent, unblocked_parent]
          inheritance_manager.stub(:parents => parents)
        end

        it "returns unblocked parents" do
          returned_set = subject.unblocked_parents
          returned_set.should include unblocked_parent
        end

        it "doesn't return blocked parents" do
          returned_set = subject.unblocked_parents
          returned_set.should_not include blocked_parent
        end

        it "doesn't return itself" do
          returned_set = subject.unblocked_parents
          returned_set.should_not include subject
        end
      end

    end
  end

end
