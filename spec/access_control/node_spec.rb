require 'spec_helper'
require 'access_control/behavior'
require 'access_control/configuration'
require 'access_control/node'

module AccessControl

  describe ".Node" do

    specify "when the argument is a Node, returns it untouched" do
      node = stub_model(Node)
      return_value = AccessControl::Node(node)

      return_value.should == node
    end

    specify "when the argument is a Securable, returns its .ac_node" do
      node = stub_model(Node)
      securable = stub("Securable", :ac_node => node)
      securable.extend(Securable)

      return_value = AccessControl::Node(securable)
      return_value.should == node
    end

    specify "launches Exception for non-recognized argument types" do
      random_object = stub.as_null_object

      lambda {
        AccessControl::Node(random_object)
      }.should raise_error(AccessControl::UnrecognizedSecurable)
    end
  end

  describe Node do
    def build_node(properties = {})
      properties[:securable_type] ||= "AccessControl::GlobalRecord"
      properties[:securable_id]   ||= 1

      Node.store(properties)
    end

    describe ".store" do
      it "returns a new Node and creates its persistent" do
        pending('review stub when #persist is reimplemented')
        properties = {:securable_type => 'Foo'}
        persistent = stub(:new_record? => true,
                          :save! => nil, :securable_type= => nil, :id => 10)
        Node::Persistent.stub(:new).and_return(persistent)

        node = Node.store(properties)
        node.persistent.should == persistent
      end

      it "accepts the securable_class option correctly" do
        node = Node.store(:securable_class => Hash, :securable_id => 1234)
        node.securable_class.should == Hash
        node.securable_type.should  == 'Hash'
      end

      it "prefers 'securable_class' over 'securable_type'" do
        node = Node.store(:securable_class => Hash, :securable_id => 1234,
                          :securable_type  => "String")

        node.securable_class.should == Hash
        node.securable_type.should  == 'Hash'
      end
    end

    describe "#persist" do
      def stub_persistent(stubs = {})
        stubs[:save!] ||= true
        stubs[:id]    ||= 1234

        stub("Persistent node", stubs)
      end

      def stub_assignment(stubs = {})
        stubs[:save!] ||= true

        stub("Assignment", stubs).tap do |assignment|
          assignment.singleton_class.class_eval do
            attr_accessor :id
          end
        end
      end

      context "when the node is a new record" do
        let(:persistent) { stub_persistent(:new_record? => true) }
        subject          { Node.wrap(persistent) }

        it "calls save! on the underlying persistent node" do
          pending('reimplement #persist to return true or false')
          persistent.should_receive(:save!)
          subject.persist
        end

        it "sets the persistent's id into the assignments" do
          pending('reimplement #persist to return true or false')
          subject.assignments << assignment1 = stub_assignment
          subject.assignments << assignment2 = stub_assignment

          assignment1.should_receive(:id=).with(persistent.id)
          assignment2.should_receive(:id=).with(persistent.id)

          subject.persist
        end

        it "calls save! on each of its assignments" do
          pending('reimplement #persist to return true or false')
          subject.assignments << assignment1 = stub_assignment
          subject.assignments << assignment2 = stub_assignment

          assignment1.should_receive(:save!)
          assignment2.should_receive(:save!)

          subject.persist
        end
      end

      context "when the node is a not a new record" do
        let(:persistent) { stub_persistent(:new_record? => false) }
        subject          { Node.wrap(persistent) }

        it "calls save! on the underlying persistent node" do
          pending('reimplement #persist to return true or false')
          persistent.should_receive(:save!)
          subject.persist
        end

        it "sets the persistent's id into the assignments" do
          pending('reimplement #persist to return true or false')
          subject.assignments << assignment1 = stub_assignment
          subject.assignments << assignment2 = stub_assignment

          assignment1.should_receive(:id=).with(persistent.id)
          assignment2.should_receive(:id=).with(persistent.id)

          subject.persist
        end

        it "calls save! on each of its assignments" do
          pending('reimplement #persist to return true or false')
          subject.assignments << assignment1 = stub_assignment
          subject.assignments << assignment2 = stub_assignment

          assignment1.should_receive(:save!)
          assignment2.should_receive(:save!)

          subject.persist
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
      [ :with_type, :blocked, :unblocked,
        :granted_for, :blocked_for].each do |delegated_scope|
        it "delegates scope .#{delegated_scope} to the persistent model" do
          Node.delegated_scopes.should include(delegated_scope)
        end
      end
    end

    describe "#assignments" do

      describe "when the node is already persisted" do
        let(:securable) { FakeSecurable.new }

        subject { Node.store(:securable_class => securable.class,
                             :securable_id    => securable.id) }

        it "is a scope provided by the Assignment class" do
          assignments_scope = stub.as_null_object
          Assignment.stub(:with_node_id).and_return(assignments_scope)

          subject.assignments.should == assignments_scope
        end
      end

      describe "when the node wasn't persisted yet" do
        subject { Node.new }

        it "is an empty collection" do
          subject.assignments.should be_empty
        end

        it "keeps its members" do
          assignment = stub
          subject.assignments << assignment

          subject.assignments.should include assignment
        end
      end
    end

    describe "on #destroy" do
      let(:persistent) { stub(:new_record? => false, :id => 1234,
                               :destroy => true) }

      subject { Node.wrap(persistent) }
      let(:assignment)  { stub("Assignment", :destroy => true) }

      before do
        Assignment.stub(:with_node_id).with(subject.id).and_return([assignment])
      end

      def should_receive_without_assignment_restriction(tested_mock, method)
        manager = stub("Manager")
        AccessControl.stub(:manager => manager)

        tested_mock.should_receive(:_before_block).ordered
        tested_mock.should_receive(method).ordered
        tested_mock.should_receive(:_after_block).ordered

        manager.define_singleton_method(:without_assignment_restriction) do |&blk|
          if block_given?
            tested_mock._before_block
            blk.call
            tested_mock._after_block
          end
        end

        yield
      end

      it "calls #destroy on the 'persistent'" do
        persistent.should_receive(:destroy)
        subject.destroy
      end

      it "destroys the 'persistent' inside a unrestricted block" do
        should_receive_without_assignment_restriction(persistent, :destroy) do
          subject.destroy
        end
      end

      describe "the assignments" do
        it "are destroyed as well" do
          assignment.should_receive(:destroy)
          subject.destroy
        end

        it "are destroyed in a unrestricted block" do
          should_receive_without_assignment_restriction(assignment, :destroy) do
            subject.destroy
          end
        end
      end

    end
  end

  describe "#securable" do

    let(:model) { Class.new }
    let(:node) { Node.new(:securable_class => model,
                          :securable_id    => 1000) }

    it "gets the record by calling .unrestricted_find in the model" do
      securable = stub('securable')
      model.stub(:unrestricted_find).with(1000).and_return(securable)
      node.securable.should == securable
    end

  end

  describe "#assignments_with_roles" do
    context "for non-persisted nodes" do
      subject { Node.new }

      it "returns assignments whose #role is within the arguments" do
        subject.assignments << assignment1 = stub(:role => "role1")
        subject.assignments << assignment2 = stub(:role => "role2")
        subject.assignments << assignment3 = stub(:role => "role3")

        returned_assignments = subject.assignments_with_roles("role1, role3")
        returned_assignments.should include(assignment1, assignment3)
        returned_assignments.should_not include(assignment2)
      end
    end

    context "for persisted nodes" do
      subject { Node.wrap(stub :id => 1234, :new_record? => false) }

      it "calls the .with_roles named scope on assignments association" do
        roles = stub
        assignments = stub
        filtered_assignments = stub

        Assignment.stub(:with_node_id).with(subject.id).and_return(assignments)
        assignments.stub(:with_roles).with(roles).and_return(filtered_assignments)

        subject.assignments_with_roles(roles).should == filtered_assignments
      end
    end
  end

  describe "automatic role assignment" do

    let(:role1) { Role.new(:name => 'owner') }
    let(:role2) { Role.new(:name => 'manager') }

    let(:securable) { FakeSecurable.new }

    let(:manager) { stub("Manager") }

    before do
      role1.save!
      role2.save!

      AccessControl.stub(:manager => manager)
      manager.stub(:principal_ids => [1, 2, 3], :can! => nil)
    end

    describe "when there's one or more default roles" do

      it "assigns the default roles to current principals in the node" do
        AccessControl.config.stub!(:default_roles).
          and_return(Set.new(['owner', 'manager']))

        node = Node.store(:securable_id => securable.id,
                          :securable_class => securable.class)

        assignments = node.assignments.map do |a|
          { :node_id => a.node_id, :role_id => a.role_id,
            :principal_id => a.principal_id}
        end

        assignments.should include(:node_id => node.id,
                                   :principal_id => 1,
                                   :role_id => role1.id)
        assignments.should include(:node_id => node.id,
                                   :principal_id => 1,
                                   :role_id => role2.id)
        assignments.should include(:node_id => node.id,
                                   :principal_id => 2,
                                   :role_id => role1.id)
        assignments.should include(:node_id => node.id,
                                   :principal_id => 2,
                                   :role_id => role2.id)
        assignments.should include(:node_id => node.id,
                                   :principal_id => 3,
                                   :role_id => role1.id)
        assignments.should include(:node_id => node.id,
                                   :principal_id => 3,
                                   :role_id => role2.id)
      end

    end

    describe "when there're no default roles" do
      it "doesn't assigns the node to any role" do
        AccessControl.config.stub!(:default_roles).
          and_return(Set.new)
        node = Node.store(:securable_id => securable.id,
                          :securable_class => securable.class)
        node.assignments.should be_empty
      end
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
      subject = Node.new(:securable_type => "Hash")
      subject.securable_class.should == Hash
    end

    it "can be set using an accessor" do
      subject = Node.new(:securable_type => "Hash")
      subject.securable_class = String

      subject.securable_class.should == String
    end

    it "overrides the securable_type if explicitly set on instantiation" do
      subject = Node.new(:securable_type => "Hash",
                         :securable_class => String)

      subject.securable_class.should == String
    end

    it "sets the securable_type accordingly" do
      subject = Node.new(:securable_class => String)
      subject.securable_type.should == "String"
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
