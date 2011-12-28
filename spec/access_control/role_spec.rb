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

    it "is extended with AccessControl::Ids" do
      Role.singleton_class.should include(AccessControl::Ids)
    end

    describe ".assign_all_to" do
      let(:combination) do
        Array.new.tap do |combination|
          combination.stub(:nodes=)
          combination.stub(:principals=)
          combination.stub(:roles=)
          combination.stub(:include_existing_assignments=)
        end
      end

      let(:nodes)      { stub("Nodes collection")      }
      let(:principals) { stub("Principals collection") }

      it "sets up the nodes of the combination using its parameter" do
        combination.should_receive(:nodes=).with(nodes)
        Role.assign_all_to(principals,nodes,combination)
      end

      it "sets up the nodes of the combination using its parameter" do
        combination.should_receive(:principals=).with(principals)
        Role.assign_all_to(principals,nodes,combination)
      end

      it "sets the combination's 'roles' as being all roles" do
        roles = [Role.create!(:name => "foobar")]
        combination.should_receive(:roles=).with(roles)

        Role.assign_all_to(principals,nodes,combination)
      end

      it "sets the combination's 'include_existing_assignments' to false" do
        combination.should_receive(:include_existing_assignments=).with(false)
        Role.assign_all_to(principals,nodes,combination)
      end

      it "saves each returned assignment" do
        new_assignment = stub("New assignment")
        combination << new_assignment

        new_assignment.should_receive(:save!)
        Role.assign_all_to(principals,nodes,combination)
      end
    end

    describe ".default" do
      let(:roles_names) { ["owner"] }
      before do
        AccessControl.config.stub(:default_roles => roles_names)
      end

      it "contains roles whose name is in config.default_roles" do
        role = Role.create!(:name => "owner")
        Role.default.should include role
      end

      it "doesn't contain roles whose name isn't in config.default_roles" do
        role = Role.create!(:name => "user")
        Role.default.should_not include role
      end

      it "doesn't blow up when config returns a Set with multiple values" do
        AccessControl.config.stub(:default_roles => Set["owner", "manager"])
        role = Role.create!(:name => "owner")

        accessing_the_results = lambda { Role.default.include?(role) }
        accessing_the_results.should_not raise_error
      end
    end

    describe ".with_names" do
      let!(:role) { Role.create!(:name => "foo") }

      context "for string arguments" do
        it "returns roles whose name is the argument" do
          Role.with_names_in("foo").should include role
        end

        it "doesn't return roles whose name isn't argument" do
          Role.with_names_in("bar").should_not include role
        end
      end

      context "for set arguments" do
        it "returns roles whose name is included in the set" do
          names = Set["foo", "bar"]
          Role.with_names_in(names).should include role
        end

        it "doesn't return roles whose name isn't included in the set" do
          names = Set["baz", "bar"]
          Role.with_names_in(names).should_not include role
        end
      end
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

    describe ".local_assignables" do

      it "returns only roles with local = true" do
        r1 = Role.create!(:name => 'local unassignable', :local => false)
        r2 = Role.create!(:name => 'local assignable', :local => true)
        Role.local_assignables.should == [r2]
      end

    end

    describe ".global_assignables" do

      it "returns only roles with global = true" do
        r1 = Role.create!(:name => 'global unassignable', :global => false)
        r2 = Role.create!(:name => 'global assignable', :global => true)
        Role.global_assignables.should == [r2]
      end

    end

    describe ".for_permission" do
      let(:item) { stub('security policy item', :role_id => 'some id') }
      let(:proxy) { stub('security policy items proxy') }
      before do
        SecurityPolicyItem.stub(:with_permission).and_return(proxy)
        proxy.stub(:role_ids).and_return('role ids')
      end

      it "gets all relevant security policy items" do
        SecurityPolicyItem.should_receive(:with_permission).
          with('some permission').and_return(proxy)
        Role.for_permission('some permission')
      end

      it "gets all role ids from them" do
        proxy.should_receive(:role_ids)
        Role.for_permission('some permission')
      end

      it "returns a condition over the ids" do
        Role.for_permission('some permission').proxy_options.should == {
          :conditions => { :id => 'role ids' }
        }
      end
    end

    describe "#permissions" do
      subject { Role.new }
      let(:permissions) { ['other permission', 'some permission'] }

      before do
        subject.security_policy_items = permissions.map do |perm|
          stub_model(SecurityPolicyItem, :permission => perm)
        end
      end

      it "returns the permissions from its security policy items" do
        subject.permissions.should include(*permissions)
      end

      it "doesn't return duplicated permissions" do
        subject.permissions.length.should == permissions.length
      end
    end

    describe "#assign_to" do

      let(:association_proxy) { stub('association proxy') }
      let(:global_node) { stub_model(Node) }
      let(:principal) { stub_model(Principal) }
      let(:role) { Role.new }

      before do
        AccessControl.stub(:global_node).and_return(global_node)
        role.stub(:assignments).and_return(association_proxy)
        association_proxy.stub(:find_or_create_by_principal_id_and_node_id)
      end

      def make_assignment
        role.assign_to(principal)
      end

      context "without specifying a context" do
        context "when an assignment already exists" do
          before do
            association_proxy.stub(:find_by_principal_id_and_node_id).
              with(principal.id, global_node.id).
              and_return('existing assignment')
          end

          it "returns the assignment" do
            role.assign_to(principal).should == 'existing assignment'
          end
        end

        context "when no assignment exists" do
          before do
            association_proxy.stub(:find_by_principal_id_and_node_id).
              with(principal.id, global_node.id).
              and_return(nil)
          end

          it "creates a new assignment" do
            association_proxy.stub(:create!).
              with(:principal_id => principal.id, :node_id => global_node.id).
              and_return('created assignment')
            make_assignment.should == 'created assignment'
          end
        end
      end

      context "specifying a context" do

        let(:context) { stub('context object') }
        let(:node) { stub_model(Node) }
        let(:contextualizer) { stub('contextualizer', :nodes => Set[node]) }

        def make_assignment
          role.assign_to(principal, context)
        end

        before { Context.stub(:new).with(context).and_return(contextualizer) }

        context "when an assignment already exists" do
          before do
            association_proxy.stub(:find_by_principal_id_and_node_id).
              with(principal.id, node.id).
              and_return('existing assignment')
          end

          it "returns the assignment" do
            role.assign_to(principal, context).should == 'existing assignment'
          end
        end

        context "when no assignment exists" do
          before do
            association_proxy.stub(:find_by_principal_id_and_node_id).
              with(principal.id, node.id).
              and_return(nil)
          end

          it "creates a new assignment" do
            association_proxy.stub(:create!).
              with(:principal_id => principal.id, :node_id => node.id).
              and_return('created assignment')
            make_assignment.should == 'created assignment'
          end
        end
      end
    end

    describe "#assigned_to" do
      it "returns roles associated with the principal provided"
    end

    describe "#assigned_to?" do

      let(:association_proxy) { stub('association proxy') }
      let(:global_node) { stub_model(Node) }
      let(:principal) { stub_model(Principal) }
      let(:user) { stub('user object', :ac_principal => principal) }
      let(:role) { Role.new }

      before do
        AccessControl.stub(:global_node).and_return(global_node)
        role.stub(:assignments).and_return(association_proxy)
        association_proxy.stub(:exists?)
      end

      def test_assignment
        role.assigned_to?(user)
      end

      it "gets the principal of the user" do
        pending("use principal instead of user, don't use options")
        user.should_receive(:ac_principal)
        test_assignment
      end

      context "without specifying a context" do

        it "gets the global node" do
          pending("use principal instead of user, don't use options")
          AccessControl.should_receive(:global_node).and_return(global_node)
          test_assignment
        end

        it "should test the existence of the role by principal and node" do
          pending("use principal instead of user, don't use options")
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
          pending("use principal instead of user, don't use options")
          Context.should_receive(:new).with(context).and_return(contextualizer)
          test_assignment
        end

        it "gets the nodes from the contextualizer" do
          pending("use principal instead of user, don't use options")
          contextualizer.should_receive(:nodes).and_return(Set[node])
          test_assignment
        end

        it "should test the existence of the role by principal and node" do
          pending("use principal instead of user, don't use options")
          association_proxy.should_receive(:exists?).with(
            :principal_id => principal,
            :node_id => node
          )
          test_assignment
        end

      end

    end

    describe "#unassign_from" do
      it "unassigns a principal from the role"
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
