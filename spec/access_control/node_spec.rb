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

    let(:manager) { Manager.new }

    def securable
      stub_model(SecurableObj)
    end

    before do
      AccessControl.clear_global_node_cache
      AccessControl.stub(:manager).and_return(manager)
      Principal.create_anonymous_principal!
      class Object::SecurableObj < ActiveRecord::Base
        set_table_name 'records'
      end
    end

    after do
      Object.send(:remove_const, 'SecurableObj')
    end

    it "is extended with AccessControl::Ids" do
      singleton_class = (class << Node; self; end)
      singleton_class.should include(AccessControl::Ids)
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
      let(:node1) do
        Node.create!(:securable_type => 'SomeType', :securable_id => '2341')
      end
      let(:node2) do
        Node.create!(:securable_type => 'AnotherType', :securable_id => '2341')
      end

      subject { Node.with_type('SomeType') }

      it { should discover(node1) }
      it { should_not discover(node2) }

      context "using an array" do
        subject { Node.with_type(['SomeType', 'AnotherType']) }
        it { should discover(node1, node2) }
      end
    end

    describe ".blocked and .unblocked" do
      let(:blocked_node) do
        Node.create!(:securable_type => 'Foo', :securable_id => 0,
                     :block => true)
      end
      let(:unblocked_node) do
        Node.create!(:securable_type => 'Foo', :securable_id => 0,
                     :block => false)
      end

      describe ".blocked" do
        subject { Node.blocked }
        it { should discover(blocked_node) }
        it { should_not discover(unblocked_node) }
      end

      describe ".unblocked" do
        subject { Node.unblocked }
        it { should discover(unblocked_node) }
        it { should_not discover(blocked_node) }
      end
    end

    describe ".granted_for" do
      let(:node_ids)    { [1, 2] }
      let(:assignments) { stub('assignments', :node_ids => node_ids) }
      let(:nodes) do
        count = 0 # This variable makes securable_id unique.
        [
          [node_ids.first,      'RightType'],
          [node_ids.second,     'WrongType'],
          [node_ids.second + 1, 'RightType'],
          [node_ids.second + 2, 'WrongType'],
        ].map do |id, type|
          count += 1
          node = Node.create!(:securable_type => type, :securable_id => count)
          Node.connection.execute(
            "UPDATE #{Node.quoted_table_name} "\
            "SET `id` = #{id} WHERE id = #{node.id}"
          )
          node.stub(:id).and_return(id)
          node
        end
      end

      let(:nodes_with_the_right_attributes) do
        items_from(nodes).with(:securable_type => 'RightType',
                               :id => node_ids.first)
      end

      before do
        Assignment.stub(:granting_for_principal).and_return(assignments)
      end

      subject { get_granted_nodes }

      def get_granted_nodes
        Node.granted_for('RightType', 'principal ids', 'permissions')
      end

      it "gets relevant assignments for permission and principal" do
        Assignment.should_receive(:granting_for_principal).
          with('permissions', 'principal ids').and_return(assignments)
        get_granted_nodes
      end

      it "gets only the ids" do
        assignments.should_receive(:node_ids).and_return('node ids')
        get_granted_nodes
      end

      it { should discover(*nodes_with_the_right_attributes) }
      it { subject.respond_to?(:sql).should be_true }
    end

    describe ".blocked_for" do

      let(:nodes) do
        count = 0
        combine_values(:securable_type => ['RightType', 'WrongType'],
                       :block => [true, false]) do |attrs|
          count += 1
          Node.create!(attrs.merge(:securable_id => count))
        end
      end

      subject { Node.blocked_for('RightType') }

      it { should discover(*items_from(nodes).
                           with(:securable_type => 'RightType',
                                :block => true)) }

      it { subject.respond_to?(:sql).should be_true }
    end

    describe "#assignments" do

      before { AccessControl.create_global_node! }

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
          assignment.should_receive(:destroy)
          node.destroy
        end

        it "destroys the assignment in a unrestricted block" do
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

      it "accepts nested attributes" do
        node = Node.new(
          :securable_type => 'Foo',
          :securable_id => 1,
          :assignments_attributes => {
            '0' => {:role_id => 1, :principal_id => 1}
          }
        )
        node.assignments.first.node_id.should == node.id
        node.assignments.first.role_id.should == 1
        node.assignments.first.principal_id.should == 1
      end

      it "allows destruction of assignments" do
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
        securable = stub('securable')
        model.should_receive(:unrestricted_find).with(1000).
          and_return(securable)
        node.securable.should == securable
      end

    end

    describe "#principal_roles" do

      it "returns only the roles belonging to the current principals" do
        AccessControl.create_global_node!
        node = Node.create!(:securable_type => 'Foo', :securable_id => 1)
        principal1 = Principal.create!(:subject_type => 'User',
                                       :subject_id => 1)
        principal2 = Principal.create!(:subject_type => 'User',
                                       :subject_id => 2)
        principal3 = Principal.create!(:subject_type => 'User',
                                       :subject_id => 3)
        role1 = Role.create!(:name => 'Role 1')
        role2 = Role.create!(:name => 'Role 2')
        role3 = Role.create!(:name => 'Role 3')
        assignment1 = Assignment.create!(:role_id => role1.id,
                                         :principal_id => principal1.id,
                                         :node_id => node.id)
        assignment2 = Assignment.create!(:role_id => role2.id,
                                         :principal_id => principal2.id,
                                         :node_id => node.id)
        assignment3 = Assignment.create!(:role_id => role3.id,
                                         :principal_id => principal3.id,
                                         :node_id => node.id)
        manager.stub!(:principal_ids).
          and_return([principal1.id, principal3.id])
        node.reload.principal_roles.should include(role1)
        node.principal_roles.should include(role3)
        node.principal_roles.should_not include(role2)
      end

      describe "conditions optimization" do

        describe "conditions with single principal" do
          it "uses the single element of the `principal_ids` from manager" do
            manager.should_receive(:principal_ids).and_return(['principal id'])
            Node.reflections[:principal_roles].
              through_reflection.options[:conditions].should == {
                :principal_id => 'principal id'
              }
          end
        end

        describe "conditions with multiple principals" do
          it "passes along all principal ids from manager in an array" do
            manager.should_receive(:principal_ids).
              and_return(['principal id1', 'principal id2'])
            Node.reflections[:principal_roles].
              through_reflection.options[:conditions].should == {
                :principal_id => ['principal id1', 'principal id2']
              }
          end
        end
      end

    end

    describe "#assignments_with_roles" do
      it "calls .with_roles named scope on assignments association" do
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

      before do
        manager.stub!(:principal_ids => [1, 2, 3], :can! => nil)
        role1; role2;
      end

      describe "when there's one or more default roles" do

        it "assigns the default roles to current principals in the node" do
          AccessControl.config.stub!(:default_roles_on_create).
            and_return(Set.new(['owner', 'manager']))

          node = Node.create!(:securable_id => securable.id,
                              :securable_type => securable.class.name).reload

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
          AccessControl.config.stub!(:default_roles_on_create).
            and_return(Set.new)
          node = Node.create!(:securable_id => securable.id,
                              :securable_type => securable.class.name).reload
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
          manager.should_receive(:can!).
            with('change_inheritance_blocking', node)
          node.block = true
        end

      end

      describe "when unblocking" do

        before do
          manager.stub(:can!)
          node.block = true
        end

        it "checks if the user has 'change_inheritance_blocking'" do
          manager.should_receive(:can!).
            with('change_inheritance_blocking', node)
          node.block = false
        end

      end

    end

    describe "the securable's class" do
      it "is, by default, induced from the securable_type string" do
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
    end

    describe "inheritance-related methods" do
      subject { Node.new(:inheritance_manager => inheritance_manager) }

      let(:inheritance_manager) { stub("Inheritance manager") }

      context "on blocked nodes" do
        before { subject.block = true }

        describe "#ancestors" do
          it "returns only the Node" do
            subject.ancestors.should == Set[subject]
          end
        end

        describe "#strict_ancestors" do
          it "returns an empty Set" do
            subject.strict_ancestors.should == Set.new
          end
        end

        describe "#unblocked_ancestors" do
          it "returns only the Node" do
            subject.unblocked_ancestors.should == Set[subject]
          end
        end

        describe "#strict_unblocked_ancestors" do
          it "returns an empty Set" do
            subject.strict_unblocked_ancestors.should == Set.new
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

          it "forwards a received 'filter' to inheritance_manager" do
            filter = Proc.new {}
            inheritance_manager.should_receive(:ancestors).with(filter)

            subject.strict_ancestors(filter)
          end
        end

        describe "#ancestors" do
          it "is Set generated by inheritance_manager, plus the node" do
            ancestor = stub
            inheritance_manager.stub(:ancestors => Set[ancestor])

            subject.ancestors.should == Set[ancestor, subject]
          end

          it "forwards a received 'filter' to inheritance_manager" do
            filter = proc {}

            inheritance_manager.stub(:ancestors).with(filter).
              and_return(Set.new)

            subject.ancestors(filter)
          end
        end

        describe "#strict_unblocked_ancestors" do
          let(:unblocked_ancestor) { stub("unblocked", :block => false) }
          let(:blocked_ancestor)   { stub("blocked",   :block => true) }

          before do
            inheritance_manager.stub(:ancestors) do |filter|
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
            inheritance_manager.stub(:ancestors) do |filter|
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

      end
    end

  end
end
