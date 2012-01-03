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

    describe "#principals" do

      describe "when there's no subject set" do
        describe "in web requests" do
          before do
            manager.use_anonymous!
          end
          it "returns the anonymous principal id" do
            Principal.should_receive(:anonymous).
              and_return("the anonymous principal")
            manager.principals.should == ["the anonymous principal"]
          end
        end
        describe "outside web requests" do
          before do
            manager.do_not_use_anonymous!
          end
          it "returns the unrestricted principal id" do
            manager.principals.should == [UnrestrictablePrincipal.instance]
          end
        end
      end

      describe "when there's a subject set" do
        before { manager.current_subjects = [subject] }
        it "gets the principal from the user" do
          manager.principals.map(&:id).should include(principal.id)
        end
        it "doesn't include the anonymous principal" do
          manager.principals.size.should == 1
        end
      end

      describe "caching" do

        before do
          manager.current_subjects = [subject]
        end

        it "smartly caches stuff" do
          manager.principals
          subject.should_not_receive(:ac_principal)
          manager.principals
        end

        it "clears the cache if current_subjects is set" do
          manager.principals
          subject.should_receive(:ac_principal)
          manager.current_subjects = [subject]
          manager.principals
        end

      end

    end

    describe "#can?" do

      let(:nodes)       { stub("Nodes collection") }
      let(:inspector)   { stub("Inspector", :permissions => permissions) }
      let(:permissions) { Set["p1", "p2"] }

      before do
        PermissionInspector.stub(:new).with(nodes).and_return(inspector)
        manager.use_anonymous! # Simulate a web request
      end

      it "returns true if the nodes grant all the given permissions" do
        return_value = manager.can?(permissions, nodes)
        return_value.should be_true
      end

      it "returns false if the nodes don't grant any of the permissions" do
        return_value = manager.can?(%w[p3 p4 p5], nodes)
        return_value.should be_false
      end

      it "returns false if the nodes don't grant one of the permissions" do
        return_value = manager.can?(%w[p1 p2 p3], nodes)
        return_value.should be_false
      end

      context "when the UnrestrictableUser exists and is logged in" do
        before do
          manager.current_subjects = [UnrestrictableUser.instance]
        end

        it "returns true without any further verification" do
          manager.can?('any permissions', 'any nodes').should be_true
        end
      end

    end

    describe "#can!" do

      let(:nodes)         { stub("Nodes collection") }
      let(:inspector)     { stub("Inspector") }
      let(:permissions)   { Set["p1", "p2"] }
      let(:current_roles) { Set["user"] }

      before do
        inspector.stub(:permissions   => permissions)
        inspector.stub(:current_roles => current_roles)

        PermissionInspector.stub(:new).and_return(inspector)
        manager.use_anonymous! # Simulate a web request
      end

      context "when the user has the permissions" do
        it "doesn't raise the 'Unauthorized' exception" do
          lambda {
            manager.can!(permissions, nodes)
          }.should_not raise_exception(::AccessControl::Unauthorized)
        end
      end

      context "when the user doesn't have the permissions" do
        let(:missing_permissions) { Set["p4", "p5"] }

        before do
          AccessControl::Util.stub(:log_missing_permissions)
        end

        it "raises the 'Unauthorized' exception" do
          lambda {
            manager.can!(missing_permissions, nodes)
          }.should raise_exception(AccessControl::Unauthorized)
        end

        it "logs the invalid permission request" do
          log_arguments = [missing_permissions, permissions,
                           current_roles, instance_of(Array)]

          AccessControl::Util.should_receive(:log_missing_permissions).
            with(*log_arguments)

          begin
            manager.can!(missing_permissions, nodes)
          rescue AccessControl::Unauthorized
          end
        end
      end

    end

    describe "assignment verification flag" do

      # The flag #(un)restrict_assignment_or_unassignment(!/?) controls whether
      # or not assignment verification should be done.

      before do
        manager.use_anonymous! # Simulate a web request
      end

      describe "#restrict_assignment_or_unassignment?" do
        it "is true by default" do
          manager.restrict_assignment_or_unassignment?.should be_true
        end

        it "can be turned off by calling "\
           "#unrestrict_assignment_or_unassignment!" do
          manager.unrestrict_assignment_or_unassignment!
          manager.restrict_assignment_or_unassignment?.should be_false
        end

        it "can be turned on by calling "\
           "#restrict_assignment_or_unassignment!" do
          manager.unrestrict_assignment_or_unassignment!
          manager.restrict_assignment_or_unassignment!
          manager.restrict_assignment_or_unassignment?.should be_true
        end

        describe "when the UnrestrictableUser is logged in" do

          before do
            manager.current_subjects = [UnrestrictableUser.instance]
          end

          it "returns false" do
            manager.restrict_assignment_or_unassignment?.should be_false
          end

        end
      end
    end

    describe "#can_assign_or_unassign?" do

      # In general: an assignment can be created/updated/destroyed if the user
      # mets one of the following:
      #
      # - Has `grant_roles`.  This permission allows the user to grant roles
      # (that is, make assignments) anywhere, for any other principal)
      #
      # - Has `share_own_roles`.  This permission allows the user to grant only
      # its roles to someone else.
      #
      # - Is the UnrestrictableUser.
      #
      # If the assignment/unassignment restriction flag is disabled then
      # nothing is required from the user and there's no restriction.

      let(:node) { stub('node') }
      let(:role) { stub('role') }
      let(:inspector) { mock('inspector') }

      before do
        PermissionInspector.stub(:new).with(node).and_return(inspector)
        manager.use_anonymous! # Simulate a web request
      end

      it "returns true if has user has 'grant_roles'" do
        inspector.stub(:has_permission?).
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
          inspector.stub(:current_roles => Set[role])
          manager.can_assign_or_unassign?(node, role).should be_true
        end

        it "returns false if the user hasn't the role being assigned" do
          inspector.stub(:current_roles => Set.new)
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

        it "returns true without any further verification on node or role" do
          manager.can_assign_or_unassign?('any node', 'any role').should be_true
        end

      end

      describe "when the restriction flag is disabled" do

        before do
          manager.stub(:restrict_assignment_or_unassignment?).and_return(false)
        end

        it "returns true without any further verification on node or role" do
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
        manager.stub(:use_anonymous?).and_return(true) # Simulate web request
      end

      describe "when restriction was restricted previously" do

        before do
          manager.restrict_queries!
        end

        it "executes a block without query restriction" do
          manager.restrict_queries!
          manager.without_query_restriction do
            manager.restrict_queries?.should be_false
          end
        end

        it "restricts queries after the block is run" do
          manager.without_query_restriction {}
          manager.restrict_queries?.should be_true
        end

        it "restricts queries even if the block raises an exception" do
          manager.without_query_restriction {
            raise StandardError
          } rescue nil
          manager.restrict_queries?.should be_true
        end

        it "raises any exception the block have raised" do
          exception = Class.new(StandardError)
          lambda {
            manager.without_query_restriction { raise exception }
          }.should raise_exception(exception)
        end

        it "returns the value returned by the block" do
          manager.without_query_restriction{'a value returned by the block'}.
            should == 'a value returned by the block'
        end

      end

      describe "when restriction was unrestricted previously" do

        before do
          manager.unrestrict_queries!
        end

        it "executes a block without query restriction" do
          manager.restrict_queries!
          manager.without_query_restriction do
            manager.restrict_queries?.should be_false
          end
        end

        it "unrestricts queries after the block is run" do
          manager.without_query_restriction {}
          manager.restrict_queries?.should be_false
        end

        it "restricts queries even if the block raises an exception" do
          manager.without_query_restriction {
            raise StandardError
          } rescue nil
          manager.restrict_queries?.should be_false
        end

        it "raises any exception the block have raised" do
          exception = Class.new(StandardError)
          lambda {
            manager.without_query_restriction { raise exception }
          }.should raise_exception(exception)
        end

        it "returns the value returned by the block" do
          manager.without_query_restriction{'a value returned by the block'}.
            should == 'a value returned by the block'
        end

      end

    end

    describe "#without_assignment_restriction" do

      before do
        manager.stub(:use_anonymous?).and_return(true) # Simulate web request
      end

      describe "when restriction was restricted previously" do

        before do
          manager.restrict_assignment_or_unassignment!
        end

        it "executes a block without assignment restriction" do
          manager.restrict_assignment_or_unassignment!
          manager.without_assignment_restriction do
            manager.restrict_assignment_or_unassignment?.should be_false
          end
        end

        it "restricts assignments after the block is run" do
          manager.without_assignment_restriction {}
          manager.restrict_assignment_or_unassignment?.should be_true
        end

        it "restricts assignments even if the block raises an exception" do
          manager.without_assignment_restriction {
            raise StandardError
          } rescue nil
          manager.restrict_assignment_or_unassignment?.should be_true
        end

        it "raises any exception the block have raised" do
          exception = Class.new(StandardError)
          lambda {
            manager.without_assignment_restriction { raise exception }
          }.should raise_exception(exception)
        end

        it "returns the value returned by the block" do
          manager.without_assignment_restriction {
            'a value returned by the block'
          }.should == 'a value returned by the block'
        end

      end

      describe "when restriction was unrestricted previously" do

        before do
          manager.unrestrict_assignment_or_unassignment!
        end

        it "executes a block without assignment restriction" do
          manager.restrict_assignment_or_unassignment!
          manager.without_assignment_restriction do
            manager.restrict_assignment_or_unassignment?.should be_false
          end
        end

        it "unrestricts assignments after the block is run" do
          manager.without_assignment_restriction {}
          manager.restrict_assignment_or_unassignment?.should be_false
        end

        it "unrestricts assignments even if the block raises an exception" do
          manager.without_assignment_restriction {
            raise StandardError
          } rescue nil
          manager.restrict_assignment_or_unassignment?.should be_false
        end

        it "raises any exception the block have raised" do
          exception = Class.new(StandardError)
          lambda {
            manager.without_assignment_restriction { raise exception }
          }.should raise_exception(exception)
        end

        it "returns the value returned by the block" do
          manager.without_assignment_restriction {
            'a value returned by the block'
          }.should == 'a value returned by the block'
        end

      end

    end

  end
end
