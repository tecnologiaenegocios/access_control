require 'spec_helper'

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
      controller.stub!(:current_user).and_return(user)
      controller.stub!(:current_groups).and_return([group1, group2])
      user.stub(:principal).and_return(user_principal)
      group1.stub(:principal).and_return(group1_principal)
      group2.stub(:principal).and_return(group2_principal)
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

      describe "in a single context" do

        let(:node) { stub('node', :has_permission? => nil) }

        describe "with a single permission queried" do

          let(:permission) { 'a permission' }

          it "returns true if the user has the permission" do
            node.should_receive(:has_permission?).with(permission).
              and_return(true)
            manager.has_access?(node, permission).should be_true
          end

          it "returns false if the user hasn't the permission" do
            node.should_receive(:has_permission?).with(permission).
              and_return(false)
            manager.has_access?(node, permission).should be_false
          end

        end

        describe "with many permissions queried" do

          let(:permission1) { 'one permission' }
          let(:permission2) { 'other permission' }

          it "returns true if the user has all permissions queried" do
            node.should_receive(:has_permission?).
              with(permission1).and_return(true)
            node.should_receive(:has_permission?).
              with(permission2).and_return(true)
            manager.has_access?(node, [permission1, permission2]).
              should be_true
          end

          it "returns false if the user has not all permissions queried" do
            node.should_receive(:has_permission?).
              with(permission1).and_return(true)
            node.should_receive(:has_permission?).
              with(permission2).and_return(false)
            manager.has_access?(node, [permission1, permission2]).
              should be_false
          end

        end
      end

      describe "in a multiple context" do

        let(:node1) { stub('node', :has_permission? => nil) }
        let(:node2) { stub('node', :has_permission? => nil) }
        let(:node3) { stub('node', :has_permission? => nil) }

        describe "with a single permission queried" do

          let(:permission) { 'a permission' }

          it "returns true if the user has the permission in any node" do
            node1.stub!(:has_permission?).and_return(true)
            node2.stub!(:has_permission?).and_return(false)
            node3.stub!(:has_permission?).and_return(false)
            manager.has_access?([node1, node2, node3],
                                permission).should be_true

            node1.stub!(:has_permission?).and_return(false)
            node2.stub!(:has_permission?).and_return(true)
            node3.stub!(:has_permission?).and_return(false)
            manager.has_access?([node1, node2, node3],
                                permission).should be_true

            node1.stub!(:has_permission?).and_return(false)
            node2.stub!(:has_permission?).and_return(false)
            node3.stub!(:has_permission?).and_return(true)
            manager.has_access?([node1, node2, node3],
                                permission).should be_true
          end

          it "returns false if the user hasn't the permission in all nodes" do
            node1.stub!(:has_permission?).and_return(false)
            node2.stub!(:has_permission?).and_return(false)
            node3.stub!(:has_permission?).and_return(false)
            manager.has_access?([node1, node2, node3],
                                permission).should be_false
          end

        end

        describe "with many permissions queried" do

          let(:permission1) { 'one permission' }
          let(:permission2) { 'other permission' }

          it "returns true if the user has all permissions queried" do
            node1.stub!(:has_permission?).and_return(true)
            node2.stub!(:has_permission?).and_return(false)
            node3.stub!(:has_permission?).and_return(false)
            manager.has_access?([node1, node2, node3],
                                [permission1, permission2]).should be_true

            node1.stub!(:has_permission?) do |permission|
              next true if permission == permission1
              false
            end
            node2.stub!(:has_permission?) do |permission|
              next true if permission == permission2
              false
            end
            node3.stub!(:has_permission?).and_return(false)
            manager.has_access?([node1, node2, node3],
                                [permission1, permission2]).should be_true
          end

          it "returns false if the user has not all permissions queried" do
            node1.stub!(:has_permission?).and_return(false)
            node2.stub!(:has_permission?).and_return(false)
            node3.stub!(:has_permission?).and_return(false)
            manager.has_access?([node1, node2, node3],
                                [permission1, permission2]).should be_false

            node1.stub!(:has_permission?) do |permission|
              next true if permission == permission1
              false
            end
            node2.stub!(:has_permission?) do |permission|
              next true if permission == permission1
              false
            end
            node3.stub!(:has_permission?).and_return(false)
            manager.has_access?([node1, node2, node3],
                                [permission1, permission2]).should be_false
          end

        end

      end

    end

    describe "#verify_access!" do

      let(:manager) { SecurityManager.new(controller) }

      it "doesn't raise Unauthorized when the user has the permissions" do
        manager.stub!(:has_access?).and_return(true)
        lambda {
          manager.verify_access!('some contexts', 'some permissions')
        }.should_not raise_exception(::AccessControl::Unauthorized)
      end

      it "raises Unauthorized when the user has no permissions" do
        manager.stub!(:has_access?).and_return(false)
        lambda {
          manager.verify_access!('some contexts', 'some permissions')
        }.should raise_exception(::AccessControl::Unauthorized)
      end

    end

    # let(:permissions) { Set.new(['permission 1', 'permission 2']) }

    # describe "context is nil (root)" do
    #   it "raise Unauthorized if user has not all required permissions" do
    #     SecurityPolicyItem.should_receive(:permission_names_for).
    #       with('some roles').and_return(Set.new)
    #     sm = SecurityManager.new(user, controller)
    #     lambda {
    #       sm.verify_permissions(nil, permissions)
    #     }.should raise_exception(Unauthorized)
    #   end

    #   it "doesn't raise if the user has all required permissions" do
    #     SecurityPolicyItem.should_receive(:permission_names_for).
    #       with('some roles').and_return(permissions)
    #     sm = SecurityManager.new(user, controller)
    #     lambda {
    #       sm.verify_permissions(nil, permissions)
    #     }.should_not raise_exception
    #   end
    # end

    # describe "context is not nil" do
    #   it "raise Unauthorized if user has not all required permissions" do
    #     SecurityPolicyItem.should_receive(:permission_names_for).
    #       with('some other roles').and_return(Set.new)
    #     sm = SecurityManager.new(user, controller)
    #     lambda {
    #       sm.verify_permissions('some context', Set.new('some permission'))
    #     }.should raise_exception(Unauthorized)
    #   end

    #   it "doesn't raise if the user has all required permissions" do
    #     SecurityPolicyItem.should_receive(:permission_names_for).
    #       with('some other roles').and_return(permissions)
    #     sm = SecurityManager.new(user, controller)
    #     lambda {
    #       sm.verify_permissions('some context', permissions)
    #     }.should_not raise_exception
    #   end
    # end

    # describe "method verification" do
    #   let(:object) { stub('object') }

    #   it "doesn't raise exception if the context is not securable" do
    #     object.stub!(:securable?).and_return(false)
    #     sm = SecurityManager.new(user, controller)
    #     lambda {
    #       sm.verify_method(object, :some_method)
    #     }.should_not raise_exception
    #   end

    #   it "doesn't raise exception if the context has no parent" do
    #     object.stub!(:securable?).and_return(true)
    #     object.stub!(:parent).and_return(nil)
    #     sm = SecurityManager.new(user, controller)
    #     lambda {
    #       sm.verify_method(object, :some_method)
    #     }.should_not raise_exception
    #   end

    #   describe "given the user has not all permissions" do
    #     it "raises Unauthorized" do
    #       object.stub!(:securable?).and_return(true)
    #       object.stub!(:parent).and_return('some not nil')
    #       object.stub!(:class).and_return(
    #         stub('obj class', :permissions_for => permissions)
    #       )
    #       SecurityPolicyItem.should_receive(:permission_names_for).
    #         with('some other roles').and_return(Set.new)
    #       sm = SecurityManager.new(user, controller)
    #       lambda {
    #         sm.verify_method(object, :some_method)
    #       }.should raise_exception(Unauthorized)
    #     end
    #   end

    #   describe "given the user has all permissions" do
    #     it "doesn't raise Unauthorized" do
    #       object.stub!(:securable?).and_return(true)
    #       object.stub!(:parent).and_return('some not nil')
    #       object.stub!(:class).and_return(
    #         stub('obj class', :permissions_for => permissions)
    #       )
    #       SecurityPolicyItem.should_receive(:permission_names_for).
    #         with('some other roles').and_return(permissions)
    #       sm = SecurityManager.new(user, controller)
    #       lambda {
    #         sm.verify_method(object, :some_method)
    #       }.should_not raise_exception
    #     end
    #   end

    # end

  end
end
