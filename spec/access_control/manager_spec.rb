require 'spec_helper'
require 'access_control/manager'

module AccessControl
  describe Manager do

    let(:principal) { stub('principal', :id => "user principal's id") }
    let(:subject) { mock('subject', :ac_principal => principal) }
    let(:manager) { Manager.new }

    before do
      Principal.stub(:anonymous_id).and_return("the anonymous' id")
    end

    describe "#use_anonymous!, #use_anonymous? and #do_not_use_anonymous!" do

      # These method makes an unlogged user to be iterpreted as the anonymous
      # user or the urestrictable user.  The default behavior in web requests
      # is to use anonymous, whilst outside requests is to use the
      # unrestrictable user (use_anonymous? => false).

      it "doesn't use anonymous by default" do
        manager.use_anonymous?.should be_false
      end

      it "can be instructed to use anonymous" do
        manager.use_anonymous!
        manager.use_anonymous?.should be_true
      end

      it "can be instructed to not use anonymous" do
        manager.use_anonymous!
        manager.do_not_use_anonymous!
        manager.use_anonymous?.should be_false
      end

    end

    describe "#current_subjects=" do

      # Setter for telling the manager what are the current principals.

      it "accepts an array of instances" do
        manager.current_subjects = [subject]
      end

      it "accepts a set of instances" do
        manager.current_subjects = Set.new([subject])
      end

      it "complains if the instance doesn't provide an #ac_principal method" do
        lambda {
          manager.current_subjects = [mock('subject')]
        }.should raise_exception(InvalidSubject)
      end

      it "gets the ac_principal from each instance" do
        subject.should_receive(:ac_principal).and_return(principal)
        manager.current_subjects = [subject]
      end

      it "makes the subject's principals available in current_principals" do
        manager.current_subjects = [subject]
        manager.current_principals.should == Set.new([principal])
      end

    end

    describe "#principal_ids" do

      describe "when there's no subject set" do
        describe "in web requests" do
          before do
            manager.use_anonymous!
          end
          it "returns the anonymous principal id" do
            Principal.should_receive(:anonymous_id).
              and_return("the anonymous' id")
            manager.principal_ids.should == ["the anonymous' id"]
          end
        end
        describe "outside web requests" do
          before do
            manager.do_not_use_anonymous!
          end
          it "returns the unrestricted principal id" do
            manager.principal_ids.should == [UnrestrictablePrincipal::ID]
          end
        end
      end

      describe "when there's a subject set" do
        before { manager.current_subjects = [subject] }
        it "gets the principal from the user" do
          manager.principal_ids.should include(principal.id)
        end
        it "doesn't include the anonymous principal id" do
          manager.principal_ids.size.should == 1
        end
      end

      describe "caching" do

        before do
          manager.current_subjects = [subject]
        end

        it "smartly caches stuff" do
          manager.principal_ids
          subject.should_not_receive(:ac_principal)
          manager.principal_ids
        end

        it "clears the cache if current_subjects is set" do
          manager.principal_ids
          subject.should_receive(:ac_principal)
          manager.current_subjects = [subject]
          manager.principal_ids
        end

      end

    end

    describe "#has_access?" do

      let(:node1) { stub('node') }
      let(:node2) { stub('node') }
      let(:inspector1) { mock('inspector', :has_permission? => nil) }
      let(:inspector2) { mock('inspector', :has_permission? => nil) }
      let(:security_context) { mock('security context', :nodes => Set.new) }

      before do
        PermissionInspector.stub(:new).with(node1).and_return(inspector1)
        PermissionInspector.stub(:new).with(node2).and_return(inspector2)
        SecurityContext.stub(:new).with('nodes').and_return(security_context)
        security_context.stub(:nodes).and_return(Set.new([node1]))
        manager.use_anonymous! # Simulate a web request
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
          manager.current_subjects = [UnrestrictableUser.instance]
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
        manager.use_anonymous! # Simulate a web request
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
        manager.use_anonymous! # Simulate a web request
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
          manager.current_subjects = [UnrestrictableUser.instance]
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

      before do
        manager.use_anonymous! # Simulate a web request
      end

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

      before do
        manager.use_anonymous! # Simulate a web request
      end

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
          manager.current_subjects = [UnrestrictableUser.instance]
        end

        it "returns false" do
          manager.restrict_queries?.should be_false
        end

      end

    end

    describe "#without_query_restriction" do

      before do
        manager.use_anonymous! # Simulate a web request
      end

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
