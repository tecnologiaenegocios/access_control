require 'spec_helper'
require 'access_control/security_manager'

describe AccessControl do

  it "can create a security manager and store it in the current thread" do
    manager = stub('security manager')
    controller = stub('a controller')
    AccessControl::SecurityManager.should_receive(:new).
      with(controller).and_return(manager)
    Thread.current.should_receive(:[]=).with(instance_of(Symbol), manager)
    AccessControl.set_security_manager(controller)
  end

  it "can get a security manager from the current thread" do
    manager = stub('security manager')
    Thread.current.should_receive(:[]).with(instance_of(Symbol)).
      and_return(manager)
    AccessControl.get_security_manager.should equal(manager)
  end

  it "can set no security manager" do
    Thread.current.should_receive(:[]=).with(instance_of(Symbol), nil)
    AccessControl.no_security_manager
  end

end

module AccessControl
  describe SecurityManager do

    let(:user) { stub_model(UserObj) }
    let(:group1) { stub_model(GroupObj) }
    let(:group2) { stub_model(GroupObj) }
    let(:controller) { stub('controller') }
    let(:user_principal) { stub('principal', :id => "user principal's id") }
    let(:group1_principal) { stub('principal', :id => "group1 principal's id") }
    let(:group2_principal) { stub('principal', :id => "group2 principal's id") }

    before do
      class Object::UserObj < ActiveRecord::Base
        def self.columns
          []
        end
      end
      class Object::GroupObj < ActiveRecord::Base
        def self.columns
          []
        end
      end
      # The methods `current_user` and `current_groups` must be called through
      # `send` because they may be protected or private.
      controller.stub!(:_through_send_current_user).and_return(user)
      controller.stub!(:_through_send_current_groups).and_return([group1, group2])
      controller.stub!(:send) do |*args|
        m = "_through_send_#{args.shift}"
        controller.__send__(m, *args)
      end
      user.stub(:principal).and_return(user_principal)
      group1.stub(:principal).and_return(group1_principal)
      group2.stub(:principal).and_return(group2_principal)

      Principal.create_anonymous_principal!
    end

    after do
      Object.send(:remove_const, 'UserObj')
      Object.send(:remove_const, 'GroupObj')
    end

    it "is created based on a controller instance" do
      SecurityManager.new(controller)
    end

    describe "#principal_ids" do

      it "gets the principal from the user" do
        user.should_receive(:principal).and_return(user_principal)
        sm = SecurityManager.new(controller)
        sm.principal_ids.should include(user_principal.id)
      end

      it "gets the principals from the groups" do
        group1.should_receive(:principal).and_return(group1_principal)
        group2.should_receive(:principal).and_return(group2_principal)
        sm = SecurityManager.new(controller)
        sm.principal_ids.should include(group1_principal.id)
        sm.principal_ids.should include(group2_principal.id)
      end

      it "combines the principals from the user and the groups" do
        SecurityManager.new(controller).principal_ids.size.should == 3
      end

      it "returns the anonymous user when controller#current_user is nil" do
        controller.stub!(:_through_send_current_user).and_return(nil)
        sm = SecurityManager.new(controller)
        sm.principal_ids.should == [Principal.anonymous_id]
      end

      it "smartly caches stuff" do
        sm = SecurityManager.new(controller)
        sm.principal_ids
        user.should_not_receive(:principal)
        group1.should_not_receive(:principal)
        group2.should_not_receive(:principal)
        sm.principal_ids
      end

    end

    describe "#has_access?" do

      let(:manager) { SecurityManager.new(controller) }
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

    end

    describe "#verify_access!" do

      let(:manager) { SecurityManager.new(controller) }

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
      let(:manager) { SecurityManager.new(controller) }

      it "computes permissions from a single node" do
        node.stub!(:permission_names).and_return([
          'permission1', 'permission2'
        ])
        manager.permissions_in_context(node).should == Set.new([
          'permission1', 'permission2'
        ])
      end

      it "computes permissions from multiple nodes" do
        node1.stub!(:permission_names).and_return([
          'permission1', 'permission2'
        ])
        node2.stub!(:permission_names).and_return([
          'permission2', 'permission3'
        ])
        manager.permissions_in_context(node1, node2).should == Set.new([
          'permission1', 'permission2', 'permission3'
        ])
      end

    end

    describe "#roles_in_context" do

      let(:node) { mock('node') }
      let(:node1) { mock('node') }
      let(:node2) { mock('node') }
      let(:manager) { SecurityManager.new(controller) }

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
      let(:manager) { SecurityManager.new(controller) }
      it "can set a flag (#restrict_queries) for restrictions" do
        manager.restrict_queries = true
      end
      it "returns the flag state through #restrict_queries?" do
        manager.restrict_queries = true
        manager.restrict_queries?.should be_true
        manager.restrict_queries = false
        manager.restrict_queries?.should be_false
        manager.restrict_queries = nil
        manager.restrict_queries?.should be_false
      end
      it "defaults the flag to true" do
        manager.restrict_queries?.should be_true
      end
    end

  end
end
