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

      let(:node1) { stub('node', :has_permission? => nil) }
      let(:node2) { stub('node', :has_permission? => nil) }

      describe "with a single permission queried" do

        let(:permission) { 'a permission' }

        it "returns true if the user has the permission" do
          node1.should_receive(:has_permission?).with(permission).
            and_return(true)
          manager.has_access?(node1, permission).should be_true
        end

        it "returns false if the user hasn't the permission" do
          node1.should_receive(:has_permission?).with(permission).
            and_return(false)
          manager.has_access?(node1, permission).should be_false
        end

        it "returns true if the user has the permission in any of the nodes" do
          node1.stub!(:has_permission? => true)
          node2.stub!(:has_permission? => false)
          manager.has_access?([node1, node2], permission).should be_true
        end

        it "returns false if the user hasn't the permission in all nodes" do
          node1.stub!(:has_permission? => false)
          node2.stub!(:has_permission? => false)
          manager.has_access?([node1, node2], permission).should be_false
        end

        it "accepts records instead of nodes" do
          node1.stub!(:has_permission? => true)
          node2.stub!(:has_permission? => false)
          record1 = stub('record', :ac_node => node1)
          record2 = stub('record', :ac_node => node2)
          manager.has_access?([record1, record2], permission).should be_true
        end

      end

      describe "with many permissions queried" do

        let(:permission1) { 'one permission' }
        let(:permission2) { 'other permission' }

        it "returns true if the user has all permissions queried" do
          node1.should_receive(:has_permission?).
            with(permission1).and_return(true)
          node1.should_receive(:has_permission?).
            with(permission2).and_return(true)
          manager.has_access?(node1, [permission1, permission2]).
            should be_true
        end

        it "returns false if the user has not all permissions queried" do
          node1.should_receive(:has_permission?).
            with(permission1).and_return(true)
          node1.should_receive(:has_permission?).
            with(permission2).and_return(false)
          manager.has_access?(node1, [permission1, permission2]).
            should be_false
        end

        it "returns true if the user has all permissions in one node" do
          node1.stub!(:has_permission? => true)
          node2.stub!(:has_permission? => false)
          manager.has_access?([node1, node2], [permission1, permission2]).
            should be_true
        end

        it "returns true if the user has all permissions combining nodes" do
          node1.stub!(:has_permission?) do |permission|
            next true if permission == permission1
            false
          end
          node2.stub!(:has_permission?) do |permission|
            next true if permission == permission2
            false
          end
          manager.has_access?([node1, node2], [permission1, permission2]).
            should be_true
        end

        it "returns false if user hasn't all permissions combining nodes" do
          node1.stub!(:has_permission?) do |permission|
            next true if permission == permission1
            false
          end
          node2.stub!(:has_permission?) do |permission|
            next true if permission == permission1
            false
          end
          manager.has_access?([node1, node2], [permission1, permission2]).
            should be_false
        end

      end

      describe "when the UnrestrictableUser exists and is logged in" do

        before do
          manager.current_user = UnrestrictableUser.instance
        end

        it "returns true" do
          manager.has_access?('any nodes', 'any permissions').should be_true
        end

      end

    end

    describe "#verify_access!" do

      it "passes unmodified the paramenters to `has_access?`" do
        manager.should_receive(:has_access?).
          with('some context', 'some permissions').
          and_return(true)
        manager.verify_access!('some context', 'some permissions')
      end

      it "doesn't raise Unauthorized when the user has the permissions" do
        manager.stub!(:has_access?).and_return(true)
        lambda {
          manager.verify_access!('some context', 'some permissions')
        }.should_not raise_exception(::AccessControl::Unauthorized)
      end

      it "raises Unauthorized when the user has no permissions" do
        manager.stub!(:has_access?).and_return(false)
        AccessControl::Util.stub!(:log_missing_permissions)
        lambda {
          manager.verify_access!('some context', 'some permissions')
        }.should raise_exception(::AccessControl::Unauthorized)
      end

      it "logs the exception when the user has no permissions" do
        manager.stub!(:has_access?).and_return(false)
        AccessControl::Util.should_receive(:log_missing_permissions).
          with('some context', 'some permissions', instance_of(Array))
        lambda {
          manager.verify_access!('some context', 'some permissions')
        }.should raise_exception(::AccessControl::Unauthorized)
      end

    end

    describe "#permissions_in_context" do

      let(:node) { mock('node') }
      let(:node1) { mock('node') }
      let(:node2) { mock('node') }

      it "computes permissions from a single node" do
        node.stub!(:permissions).and_return(['permission1', 'permission2'])
        manager.permissions_in_context(node).should == Set.new([
          'permission1', 'permission2'
        ])
      end

      it "computes permissions from multiple nodes" do
        node1.stub!(:permissions).and_return(['permission1', 'permission2'])
        node2.stub!(:permissions).and_return(['permission2', 'permission3'])
        manager.permissions_in_context(node1, node2).should == Set.new([
          'permission1', 'permission2', 'permission3'
        ])
      end

    end

    describe "#roles_in_context" do

      let(:node) { mock('node') }
      let(:node1) { mock('node') }
      let(:node2) { mock('node') }

      it "computes roles from a single node" do
        node.stub!(:current_roles).and_return(['role1', 'role2'])
        manager.roles_in_context(node).should == Set.new(['role1', 'role2'])
      end

      it "computes roles from multiple nodes" do
        node1.stub!(:current_roles).and_return(['role1', 'role2'])
        node2.stub!(:current_roles).and_return(['role2', 'role3'])
        manager.roles_in_context(node1, node2).should == Set.new([
          'role1', 'role2', 'role3'
        ])
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
