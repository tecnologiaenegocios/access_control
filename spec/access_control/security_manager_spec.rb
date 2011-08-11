require 'spec_helper'
require 'access_control/security_manager'

describe AccessControl do

  it "has a security manager" do
    AccessControl.security_manager.should be_a(AccessControl::SecurityManager)
  end

  it "instantiates the security manager only once" do
    first = AccessControl.security_manager
    second = AccessControl.security_manager
    first.should equal(second)
  end

  it "stores the security manager in the current thread" do
    current_security_manager = AccessControl.security_manager
    thr_security_manager = nil
    Thread.new { thr_security_manager = AccessControl.security_manager }
    current_security_manager.should_not equal(thr_security_manager)
  end

  after do
    # Clear the instantiated security manager.
    AccessControl.no_security_manager
  end

end

module AccessControl
  describe SecurityManager do

    let(:user_principal) { stub('principal', :id => "user principal's id") }
    let(:group1_principal) { stub('principal', :id => "group1 principal's id") }
    let(:group2_principal) { stub('principal', :id => "group2 principal's id") }
    let(:user) { stub('user', :principal => user_principal) }
    let(:group1) { stub('group1', :principal => group1_principal) }
    let(:group2) { stub('group2', :principal => group2_principal) }
    let(:manager) { SecurityManager.new }

    before do
      Principal.create_anonymous_principal!
      manager.current_user = user
    end

    describe "#principal_ids" do

      describe "when there's no user nor group set" do
        before do
          manager.current_user = nil
          manager.current_groups = []
        end

        it "returns the anonymous principal" do
          Principal.should_receive(:anonymous_id).and_return("the anonymous' id")
          manager.principal_ids.should == ["the anonymous' id"]
        end
      end

      describe "when there's a user set but no groups" do
        it "gets the principal from the user" do
          user.should_receive(:principal).and_return(user_principal)
          manager.principal_ids.should include(user_principal.id)
        end
      end

      describe "when there's user and groups set" do

        before do
          manager.current_user = user
          manager.current_groups = [group1, group2]
        end

        it "gets the principal from the user" do
          user.should_receive(:principal).and_return(user_principal)
          manager.principal_ids.should include(user_principal.id)
        end

        it "gets the principals from the groups" do
          group1.should_receive(:principal).and_return(group1_principal)
          group2.should_receive(:principal).and_return(group2_principal)
          manager.principal_ids.should include(group1_principal.id)
          manager.principal_ids.should include(group2_principal.id)
        end

        it "combines the principals from the user and the groups" do
          manager.principal_ids.size.should == 3
        end

      end

      describe "when there's just groups set" do

        before do
          manager.current_user = nil
          manager.current_groups = [group1, group2]
        end

        it "gets the principals from the groups" do
          group1.should_receive(:principal).and_return(group1_principal)
          group2.should_receive(:principal).and_return(group2_principal)
          manager.principal_ids.should include(group1_principal.id)
          manager.principal_ids.should include(group2_principal.id)
        end

        it "returns the anonymous principal" do
          Principal.should_receive(:anonymous_id).and_return("the anonymous' id")
          manager.principal_ids.should include("the anonymous' id")
        end
      end

      describe "caching" do

        before do
          manager.current_user = user
          manager.current_groups = [group1, group2]
        end

        it "smartly caches stuff" do
          manager.principal_ids
          user.should_not_receive(:principal)
          group1.should_not_receive(:principal)
          group2.should_not_receive(:principal)
          manager.principal_ids
        end

        it "clears the cache if current_user is set" do
          manager.principal_ids
          manager.current_user = user
          user.should_receive(:principal)
          group1.should_receive(:principal)
          group2.should_receive(:principal)
          manager.principal_ids
        end

        it "clears the cache if current_groups is set" do
          manager.principal_ids
          manager.current_groups = [group1, group2]
          user.should_receive(:principal)
          group1.should_receive(:principal)
          group2.should_receive(:principal)
          manager.principal_ids
        end

      end

    end

    describe "#has_access?" do

      let(:node1) { stub('node') }
      let(:node2) { stub('node') }
      let(:inspector1) { mock('inspector', :has_permission? => nil) }
      let(:inspector2) { mock('inspector', :has_permission? => nil) }
      let(:security_context) { mock('security context', :nodes => Set.new()) }

      before do
        PermissionInspector.stub(:new).with(node1).and_return(inspector1)
        PermissionInspector.stub(:new).with(node2).and_return(inspector2)
        SecurityContext.stub(:new).with('nodes').and_return(security_context)
        security_context.stub(:nodes).and_return(Set.new([node1]))
      end

      it "creates a inspector from the node given" do
        PermissionInspector.should_receive(:new).with(node1).
          and_return(inspector1)
        manager.has_access?('nodes', "a permission that doesn't matter")
      end

      it "uses SecurityContext to get the actual nodes" do
        SecurityContext.should_receive(:new).with('nodes').
          and_return(security_context)
        security_context.should_receive(:nodes).and_return(Set.new([node1]))
        manager.has_access?('nodes', "a permission that doesn't matter")
      end

      describe "with a single permission queried" do

        let(:permission) { 'a permission' }

        it "returns true if the user has the permission" do
          inspector1.should_receive(:has_permission?).with(permission).
            and_return(true)
          manager.has_access?('nodes', permission).should be_true
        end

        it "returns false if the user hasn't the permission" do
          inspector1.should_receive(:has_permission?).with(permission).
            and_return(false)
          manager.has_access?('nodes', permission).should be_false
        end

        it "returns true if the user has the permission in any of the nodes" do
          security_context.should_receive(:nodes).
            and_return(Set.new([node1, node2]))
          inspector1.stub(:has_permission? => true)
          inspector2.stub(:has_permission? => false)
          manager.has_access?('nodes', permission).should be_true
        end

        it "returns false if the user hasn't the permission in all nodes" do
          security_context.should_receive(:nodes).
            and_return(Set.new([node1, node2]))
          inspector1.stub(:has_permission? => false)
          inspector2.stub(:has_permission? => false)
          manager.has_access?('nodes', permission).should be_false
        end

      end

      describe "with many permissions queried" do

        let(:permission1) { 'one permission' }
        let(:permission2) { 'other permission' }

        it "returns true if the user has all permissions queried" do
          inspector1.should_receive(:has_permission?).
            with(permission1).and_return(true)
          inspector1.should_receive(:has_permission?).
            with(permission2).and_return(true)
          manager.has_access?('nodes', [permission1, permission2]).
            should be_true
        end

        it "returns false if the user has not all permissions queried" do
          inspector1.should_receive(:has_permission?).
            with(permission1).and_return(true)
          inspector1.should_receive(:has_permission?).
            with(permission2).and_return(false)
          manager.has_access?('nodes', [permission1, permission2]).
            should be_false
        end

        it "returns true if the user has all permissions in one node" do
          inspector1.stub(:has_permission? => true)
          inspector2.stub(:has_permission? => false)
          security_context.should_receive(:nodes).
            and_return(Set.new([node1, node2]))
          manager.has_access?('nodes', [permission1, permission2]).
            should be_true
        end

        it "returns true if the user has all permissions combining nodes" do
          inspector1.stub(:has_permission?) do |permission|
            next true if permission == permission1
            false
          end
          inspector2.stub(:has_permission?) do |permission|
            next true if permission == permission2
            false
          end
          security_context.should_receive(:nodes).
            and_return(Set.new([node1, node2]))
          manager.has_access?('nodes', [permission1, permission2]).
            should be_true
        end

        it "returns false if user hasn't all permissions combining nodes" do
          inspector1.stub(:has_permission?) do |permission|
            next true if permission == permission1
            false
          end
          inspector2.stub(:has_permission?) do |permission|
            next true if permission == permission1
            false
          end
          security_context.should_receive(:nodes).
            and_return(Set.new([node1, node2]))
          manager.has_access?('nodes', [permission1, permission2]).
            should be_false
        end

      end

      describe "when the UnrestrictableUser exists and is logged in" do

        before do
          manager.current_user = UnrestrictableUser.instance
        end

        it "returns true without any further verification on nodes or "\
           "permissions" do
          manager.has_access?('any nodes', 'any permissions').should be_true
        end

      end

    end

    describe "#verify_access!" do

      let(:node) { stub('node') }
      let(:security_context) do
        mock('security context', :nodes => Set.new([node]))
      end
      let(:inspector) { mock('inspector') }

      before do
        inspector.stub(:permissions).and_return(Set.new)
        PermissionInspector.stub(:new).and_return(inspector)
        SecurityContext.stub(:new).and_return(security_context)
        AccessControl::Util.stub(:log_missing_permissions)
      end

      it "passes unmodified the paramenters to `has_access?`" do
        manager.should_receive(:has_access?).
          with('some context', 'some permissions').
          and_return(true)
        manager.verify_access!('some context', 'some permissions')
      end

      it "doesn't raise Unauthorized when the user has the permissions" do
        manager.stub(:has_access?).and_return(true)
        lambda {
          manager.verify_access!('some context', 'some permissions')
        }.should_not raise_exception(::AccessControl::Unauthorized)
      end

      it "raises Unauthorized when the user has no permissions" do
        manager.stub(:has_access?).and_return(false)
        lambda {
          manager.verify_access!('some context', 'some permissions')
        }.should raise_exception(::AccessControl::Unauthorized)
      end

      it "logs the exception when the user has no permissions" do
        manager.stub(:has_access?).and_return(false)
        inspector.should_receive(:permissions).
          and_return(Set.new(['permissions']))
        AccessControl::Util.should_receive(:log_missing_permissions).
          with('some permissions', Set.new(['permissions']), instance_of(Array))
        lambda {
          manager.verify_access!('some context', 'some permissions')
        }.should raise_exception(::AccessControl::Unauthorized)
      end

    end

    describe "#can_assign_or_unassign?" do

      # In general: an assignment can be created/updated if the user
      #
      # - Has `grant_roles`.  This permission allows the user to grant roles
      # (that is, make assignments) anywhere, for any other principal)
      #
      # - Has `share_own_roles`.  This perission allows the user to grant only
      # its roles to someone else.

      let(:node) { stub('node') }
      let(:role) { stub('role') }
      let(:inspector) { mock('inspector') }

      before do
        PermissionInspector.stub(:new).with(node).and_return(inspector)
      end

      it "returns true if has user has 'grant_roles'" do
        inspector.should_receive(:has_permission?).
          with('grant_roles').and_return(true)
        manager.can_assign_or_unassign?(node, 'a role').should be_true
      end

      context "when the user has 'share_own_roles'" do

        before do
          inspector.stub(:has_permission?).with('grant_roles').
            and_return(false)
          inspector.stub(:has_permission?).with('share_own_roles').
            and_return(true)
        end

        it "returns true if the user has the role being assigned" do
          inspector.should_receive(:current_roles).and_return(Set.new([role]))
          manager.can_assign_or_unassign?(node, role).should be_true
        end

        it "returns false if the user hasn't the role being assigned" do
          inspector.should_receive(:current_roles).and_return(Set.new())
          manager.can_assign_or_unassign?(node, role).should be_false
        end

      end

      context "when the user hasn't 'share_own_roles'" do

        before do
          inspector.stub(:has_permission?).with('grant_roles').
            and_return(false)
          inspector.stub(:has_permission?).with('share_own_roles').
            and_return(false)
        end

        it "returns false" do
          manager.can_assign_or_unassign?(node, role).should be_false
        end

      end

      describe "when the UnrestrictableUser exists and is logged in" do

        before do
          manager.current_user = UnrestrictableUser.instance
        end

        it "returns true without any further verification on node or "\
           "role" do
          manager.can_assign_or_unassign?('any node', 'any role').should be_true
        end

      end

    end

    describe "#verify_assignment!" do

      let(:node) { stub('node') }
      let(:role) { stub('role') }

      it "passes unmodified the parameters to `can_assign_or_unassign?`" do
        manager.should_receive(:can_assign_or_unassign?).with(node, role).
          and_return(true)
        manager.verify_assignment!(node, role)
      end

      it "raises Unauthorized when `can_assign_or_unassign?` returns false" do
        manager.should_receive(:can_assign_or_unassign?).with(node, role).
          and_return(false)
        lambda {
          manager.verify_assignment!(node, role)
        }.should raise_exception(Unauthorized)
      end

    end

    describe "restriction in queries" do

      it "is true by default" do
        manager.restrict_queries?.should be_true
      end

      it "can be turned off by calling unrestrict_queries!" do
        manager.unrestrict_queries!
        manager.restrict_queries?.should be_false
      end

      it "can be turned on by calling restrict_queries!" do
        manager.unrestrict_queries!
        manager.restrict_queries!
        manager.restrict_queries?.should be_true
      end

      describe "when the UnrestrictableUser is logged in" do

        before do
          manager.current_user = UnrestrictableUser.instance
        end

        it "returns false" do
          manager.restrict_queries?.should be_false
        end

      end

    end

    describe "#without_query_restriction" do

      it "executes a block without query restriction" do
        manager.restrict_queries!
        manager.without_query_restriction do
          manager.restrict_queries?.should be_false
        end
      end

      it "restores back the old value of the restriction flag" do
        manager.restrict_queries!
        manager.without_query_restriction {}
        manager.restrict_queries?.should be_true
        manager.unrestrict_queries!
        manager.without_query_restriction {}
        manager.restrict_queries?.should be_false
      end

      it "returns the value returned by the block" do
        manager.without_query_restriction{'a value returned by the block'}.
          should == 'a value returned by the block'
      end

    end

  end
end
