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
        }.should raise_exception(UnrecognizedSubject)
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

      let(:global_node) { stub('Global node') }
      let(:nodes)       { stub("Nodes collection") }
      let(:inspector)   { stub("Inspector", :permissions => permissions) }
      let(:permissions) { Set["p1", "p2"] }
      let(:inspector_at_global_node) do
        stub('Inspector', :permissions => Set.new)
      end

      before do
        AccessControl.stub(:global_node).and_return(global_node)
        PermissionInspector.stub(:new).with(global_node).
          and_return(inspector_at_global_node)
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

      context "when user has the required permissions in the global node" do
        before do
          inspector_at_global_node.stub(:permissions).and_return(permissions)
          inspector.stub(:permissions).and_return(Set.new)
        end

        it "returns true" do
          return_value = manager.can?(permissions, nodes)
          return_value.should be_true
        end

        it "doesn't check permissions in the nodes given" do
          inspector.should_not_receive(:permissions)
          manager.can?(permissions, nodes)
        end
      end

    end

    describe "#can!" do

      let(:global_node)   { stub('Global node') }
      let(:nodes)         { stub("Nodes collection") }
      let(:inspector)     { stub("Inspector") }
      let(:permissions)   { Set["p1", "p2"] }
      let(:current_roles) { Set["user"] }
      let(:inspector_at_global_node) do
        stub('Inspector', :permissions => Set['p3'],
             :current_roles => ['owner'])
      end

      before do
        inspector.stub(:permissions   => permissions)
        inspector.stub(:current_roles => current_roles)
        AccessControl.stub(:global_node).and_return(global_node)

        PermissionInspector.stub(:new).with(nodes).and_return(inspector)
        PermissionInspector.stub(:new).with(global_node).
          and_return(inspector_at_global_node)
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
          log_arguments = [
            missing_permissions,
            permissions | inspector_at_global_node.permissions,
            current_roles | inspector_at_global_node.current_roles,
            instance_of(Array)
          ]

          AccessControl::Util.should_receive(:log_missing_permissions).
            with(*log_arguments)

          begin
            manager.can!(missing_permissions, nodes)
          rescue AccessControl::Unauthorized
          end
        end
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
  end
end
