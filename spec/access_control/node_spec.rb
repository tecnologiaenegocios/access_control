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
        properties = {:foo => :bar}
        persistent = stub
        Node::Persistent.stub(:create!).with(properties).and_return(persistent)

        node = Node.store(properties)
        node.persistent.should == persistent
      end
    end

    describe ".wrap" do
      it "creates a new Node whose 'persistent' is the given object" do
        object = stub
        node   = Node.wrap(object)

        node.persistent.should be object
      end
    end

    describe "delegations" do
      delegated_methods = [:block, :id, :securable_type, :securable_id]

      delegated_methods.each do |method_name|
        it "delegates '#{method_name}' to the persistent" do
          object = stub(method_name => 1234)
          node   = Node.wrap(object)

          node.public_send(method_name).should == 1234
        end
      end

      delegated_setters = [:id, :securable_type, :securable_id]

      delegated_setters.each do |property_name|
        it "delegates the '#{property_name}' setter to the persistent" do
          object = mock
          node   = Node.wrap(object)

          setter_name = "#{property_name}="
          object.should_receive(setter_name).with(1234)
          node.public_send(setter_name, 1234)
        end
      end
    end

    describe "equality comparison" do
      specify "two Nodes are equal if their persistents are equal" do
        p1 = "a persistent"
        p2 = "a persistent"

        node1 = Node.wrap(p1)
        node2 = Node.wrap(p2)

        node1.should == node2
      end

      specify "a node is never equal to an object that isn't a Node" do
        persistent = stub

        fake_node = stub(:persistent => persistent)
        node = Node.wrap(persistent)

        node.should_not == fake_node
      end
    end

    describe ".fetch" do
      let(:node) { build_node }

      it "returns the node that has the passed id" do
        node_id = node.id
        Node.fetch(node_id).should == node
      end

      context "when no node is found" do
        context "and no block is given" do
          it "raises AccessControl::NotFoundError if no default is given" do
            inexistent_id = -1
            lambda {
              Node.fetch(inexistent_id)
            }.should raise_exception(AccessControl::NotFoundError)
          end

          it "returns the default given" do
            inexistent_id = -1
            default = stub
            Node.fetch(inexistent_id, default).should be default
          end
        end

        context "and a block is given" do
          it "uses the block if no value is given" do
            inexistent_id = -1
            default = stub
            returned_value = Node.fetch(inexistent_id) { default }
            returned_value.should be default
          end

          it "uses the block even if a value is given" do
            inexistent_id = -1
            value_default = stub('value')
            block_default = stub('from block')
            returned_value = Node.fetch(inexistent_id, value_default) do
              block_default
            end

            returned_value.should be block_default
          end
        end
      end
    end

    describe ".has?" do
      let(:node) { build_node }

      it "returns true if the node with the passed ID exists" do
        node_id = node.id
        Node.has?(node_id).should be_true
      end

      it "returns false if the ID doesn't correspond to any node" do
        inexistent_id = -1
        Node.has?(inexistent_id).should be_false
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

    describe ".with_type" do
      it { pending }
    end

    describe ".blocked and .unblocked" do
      it { pending }
    end

    describe ".granted_for" do
      it { pending }
    end

    describe ".blocked_for" do
      it { pending }
    end

    describe "#assignments" do

      describe "assignment destruction" do

        let(:assignment) do
          stub_model(Assignment, :[]= => true, :save => true)
        end

        let(:node) do
          Node.new(:securable_type => 'Foo', :securable_id => 1)
        end

        before do
          Object.const_set('TestPoint', stub('testpoint'))
          node.assignments << assignment
        end

        after do
          Object.send(:remove_const, 'TestPoint')
        end

        it "destroys the dependant assignments when the node is destroyed" do
          pending
          assignment.should_receive(:destroy)
          node.destroy
        end

        it "destroys the assignment in a unrestricted block" do
          pending
          TestPoint.should_receive(:before_yield).ordered
          TestPoint.should_receive(:on_destroy).ordered
          TestPoint.should_receive(:after_yield).ordered
          manager.instance_eval do
            def without_assignment_restriction
              TestPoint.before_yield
              yield
              TestPoint.after_yield
            end
          end
          assignment.instance_eval do
            def destroy
              TestPoint.on_destroy
            end
          end
          node.destroy
        end

      end

      it "allows destruction of assignments" do
        pending
        node = Node.new(:securable_type => 'Foo', :securable_id => 1)
        assignment = stub_model(Assignment, :[]= => true, :save => true)
        node.assignments << assignment
        # A little explanation of the "twice" bit: Rails adds two callbacks for
        # an autosave association, one for the has_many declaration and
        # another for the accepts_nested_attributes_for declaration.  This
        # makes the destroy method being called twice.  If the association
        # hasn't the accepts_nested_attributes_for stuff, only one callback
        # would exist and be called, but the method destroy would not if the
        # association were not autosave.
        assignment.should_receive(:destroy).twice
        node.update_attributes(:assignments_attributes => {
          '0' => {:id => assignment.to_param, :_destroy => '1'}
        })
      end

    end

    describe "#securable" do

      # The first version of this method was an association method, which was
      # public.  Then the association was removed because it could not search
      # unrestrictly, and this method resurfaced as a private method, which
      # took its own precautions to not trigger Unauthorized errors.  But it
      # was too late...  The method was being used elsewhere, in app code and
      # app specs too...  Now the method was promoted to public, just as it was
      # when it was an association.

      let(:model) { Class.new }
      let(:node) { Node.new(:securable_type => 'SecurableType',
                            :securable_id => 1000) }
      before do
        Object.send(:const_set, 'SecurableType', model)
      end

      after do
        Object.send(:remove_const, 'SecurableType')
      end

      it "gets the record by calling .unrestricted_find in the model" do
        pending
        securable = stub('securable')
        model.should_receive(:unrestricted_find).with(1000).
          and_return(securable)
        node.securable.should == securable
      end

    end

    describe "#assignments_with_roles" do
      it "calls .with_roles named scope on assignments association" do
        pending
        node = Node.new
        roles = 'some roles to filter'
        node.stub(:assignments => mock('assignments'))
        node.assignments.should_receive(:with_roles).with(roles).
          and_return('the filtered assignments')
        node.assignments_with_roles(roles).should == 'the filtered assignments'
      end
    end

    describe "automatic role assignment" do

      let(:role1) { Role.create!(:name => 'owner') }
      let(:role2) { Role.create!(:name => 'manager') }

      # before do
      #   manager.stub!(:principal_ids => [1, 2, 3], :can! => nil)
      #   role1; role2;
      # end

      describe "when there's one or more default roles" do

        it "assigns the default roles to current principals in the node" do
          pending
          AccessControl.config.stub!(:default_roles_on_create).
            and_return(Set.new(['owner', 'manager']))

          node = Node.create!(:securable_id => securable.id,
                              :securable_class => securable_class).reload

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

      describe "when there's no default roles" do
        it "doesn't assigns the node to any role" do
          pending
          AccessControl.config.stub!(:default_roles_on_create).
            and_return(Set.new)
          node = Node.create!(:securable_id => securable.id,
                              :securable_class => securable_class).reload
          node.assignments.should be_empty
        end
      end

    end

    describe "blocking and unblocking" do

      let(:node) { Node.new }

      it "defaults to unblocked (block == false)" do
        node.block.should be_false
      end

      describe "when blocking" do

        it "checks if the user has 'change_inheritance_blocking'" do
          pending
          manager.should_receive(:can!).
            with('change_inheritance_blocking', node)
          node.block = true
        end

      end

      describe "when unblocking" do

        # before do
        #   manager.stub(:can!)
        #   node.block = true
        # end

        it "checks if the user has 'change_inheritance_blocking'" do
          pending
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
end
