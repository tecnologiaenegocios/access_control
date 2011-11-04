require 'spec_helper'
require 'access_control/role'

module AccessControl
  describe Role do

    let(:manager) { Manager.new }

    before do
      AccessControl.stub(:manager).and_return(manager)
    end

    it "validates presence of name" do
      Role.new.should have(1).error_on(:name)
    end

    it "validates uniqueness of name" do
      Role.create!(:name => 'the role name')
      Role.new(:name => 'the role name').should have(1).error_on(:name)
    end

    it "can be created with valid attributes" do
      Role.create!(:name => 'the role name')
    end

    describe "assignment destruction" do

      let(:assignment) do
        stub_model(Assignment, :[]= => true, :save => true)
      end

      let(:role) do
        Role.new(:name => 'the role name')
      end

      before do
        Object.const_set('TestPoint', stub('testpoint'))
        role.assignments << assignment
      end

      after do
        Object.send(:remove_const, 'TestPoint')
      end

      it "destroys assignments when it is destroyed" do
        assignment.should_receive(:destroy)
        role.destroy
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
        role.destroy
      end

    end

    it "destroys security policy items when it is destroyed" do
      role = Role.create!(:name => 'the role name')
      SecurityPolicyItem.create!(:role => role,
                                 :permission => 'some permission')
      role.destroy
      SecurityPolicyItem.count.should == 0
    end

    describe "#local_assignables" do

      it "returns only roles with local = true" do
        r1 = Role.create!(:name => 'local unassignable', :local => false)
        r2 = Role.create!(:name => 'local assignable', :local => true)
        Role.local_assignables.should == [r2]
      end

    end

    describe "#global_assignables" do

      it "returns only roles with global = true" do
        r1 = Role.create!(:name => 'global unassignable', :global => false)
        r2 = Role.create!(:name => 'global assignable', :global => true)
        Role.global_assignables.should == [r2]
      end

    end

    describe "#permissions" do
      it "returns the permissions from its security policy items" do
        r = Role.new
        r.security_policy_items = [
          SecurityPolicyItem.new(:permission => 'some permission'),
          SecurityPolicyItem.new(:permission => 'other permission')
        ]
        r.permissions.should == Set.new(['other permission', 'some permission'])
      end
    end

    describe "#assign_to" do

      let(:association_proxy) { stub('association proxy') }
      let(:global_node) { stub_model(Node) }
      let(:principal) { stub_model(Principal) }
      let(:user) { stub('user object', :ac_principal => principal) }
      let(:role) { Role.new }

      before do
        AccessControl::Node.stub(:global).and_return(global_node)
        role.stub(:assignments).and_return(association_proxy)
        association_proxy.stub(:find_or_create_by_principal_id_and_node_id)
      end

      def make_assignment
        role.assign_to(user)
      end

      it "gets the principal of the user" do
        user.should_receive(:ac_principal)
        make_assignment
      end

      context "without specifying a context" do

        it "gets the global node" do
          Node.should_receive(:global).and_return(global_node)
          make_assignment
        end

        it "creates an assignment in the global node or finds one if it "\
           "already exists" do
          association_proxy.
            should_receive(:find_or_create_by_principal_id_and_node_id).
            with(principal.id, global_node.id)
          make_assignment
        end

      end

      context "specifying a context" do

        let(:context) { stub('context object') }
        let(:node) { stub_model(Node) }
        let(:contextualizer) { stub('contextualizer', :nodes => Set[node]) }

        def make_assignment
          role.assign_to(user, :at => context)
        end

        before do
          Context.stub(:new).and_return(contextualizer)
        end

        it "initializes a Context object using the context provided" do
          Context.should_receive(:new).with(context).and_return(contextualizer)
          make_assignment
        end

        it "gets the nodes from the contextualizer" do
          contextualizer.should_receive(:nodes).and_return(Set[node])
          make_assignment
        end

        it "creates an assignment using the node of the context or finds one "\
           "if it already exists" do
          association_proxy.
            should_receive(:find_or_create_by_principal_id_and_node_id).
            with(principal.id, node.id)
          make_assignment
        end

      end

    end

    describe "#assigned_to?" do

      let(:association_proxy) { stub('association proxy') }
      let(:global_node) { stub_model(Node) }
      let(:principal) { stub_model(Principal) }
      let(:user) { stub('user object', :ac_principal => principal) }
      let(:role) { Role.new }

      before do
        AccessControl::Node.stub(:global).and_return(global_node)
        role.stub(:assignments).and_return(association_proxy)
        association_proxy.stub(:exists?)
      end

      def test_assignment
        role.assigned_to?(user)
      end

      it "gets the principal of the user" do
        user.should_receive(:ac_principal)
        test_assignment
      end

      context "without specifying a context" do

        it "gets the global node" do
          Node.should_receive(:global).and_return(global_node)
          test_assignment
        end

        it "should test the existence of the role by principal and node" do
          association_proxy.should_receive(:exists?).with(
            :principal_id => principal,
            :node_id => global_node
          )
          test_assignment
        end

      end

      context "specifying a context" do

        let(:context) { stub('context object') }
        let(:node) { stub_model(Node) }
        let(:contextualizer) { stub('contextualizer', :nodes => Set[node]) }

        def test_assignment
          role.assigned_to?(user, :at => context)
        end

        before do
          Context.stub(:new).and_return(contextualizer)
        end

        it "initializes a Context object using the context provided" do
          Context.should_receive(:new).with(context).and_return(contextualizer)
          test_assignment
        end

        it "gets the nodes from the contextualizer" do
          contextualizer.should_receive(:nodes).and_return(Set[node])
          test_assignment
        end

        it "should test the existence of the role by principal and node" do
          association_proxy.should_receive(:exists?).with(
            :principal_id => principal,
            :node_id => node
          )
          test_assignment
        end

      end

    end

    describe "#assign_permission" do

      let(:association_proxy) { stub('association proxy') }
      let(:permission) { 'a permission' }
      let(:role) { Role.new }

      before do
        role.stub(:security_policy_items).and_return(association_proxy)
        association_proxy.stub(:find_by_permission).and_return(nil)
        association_proxy.stub(:create!)
      end

      def make_assignment
        role.assign_permission(permission)
      end

      it "finds the permission at first" do
        association_proxy.should_receive(:find_by_permission).
          with(permission).and_return(nil)
        make_assignment
      end

      context "the permission doesn't exist" do
        it "creates a new security policy item from the assoc. proxy" do
          association_proxy.should_receive(:create!).with(
            :permission => permission
          )
          make_assignment
        end
      end

      context "the permission already exists" do
        let(:item) { stub('security policy item') }

        before do
          association_proxy.stub(:find_by_permission).and_return(item)
        end

        it "does nothing" do
          association_proxy.should_not_receive(:create!)
          make_assignment
        end
      end

    end

  end
end
