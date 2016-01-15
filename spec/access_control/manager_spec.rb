require 'spec_helper'
require 'access_control/manager'

module AccessControl
  describe Manager do

    let(:principal) { stub('principal', :id => "user principal's id") }
    let(:subject)   { mock('subject') }
    let(:manager)   { Manager.new }

    before do
      Principal.stub(:anonymous)
        .and_return(stub("the anonymous principal", id: "the anonymous' id"))
      AccessControl.stub(:Principal).with(UnrestrictableUser.instance).
        and_return(UnrestrictablePrincipal.instance)
      AccessControl.stub(:Principal).with(subject).and_return(principal)
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

      # Setter for telling the manager what are the current principals, from
      # the application point of view.

      it "accepts an array of instances" do
        manager.current_subjects = [subject]
      end

      it "accepts a set of instances" do
        manager.current_subjects = Set.new([subject])
      end

      it "makes the subject's principals available in current_principals" do
        manager.current_subjects = [subject]
        manager.current_principals.should == Set.new([principal])
      end

    end

    describe "#current_principals=" do

      # Setter for telling the manager what are the current principals, from
      # the AccessControl point of view.  This setter is more limited because it
      # is not inteded to be used by the application.

      it "sets #current_principals" do
        manager.current_principals = Set[principal]
        manager.current_principals.should == Set[principal]
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
          manager.principals.map(&:id).should include_only(principal.id)
        end
      end

      describe "caching" do

        before do
          manager.current_subjects = [subject]
        end

        it "smartly caches stuff" do
          manager.principals
          AccessControl.should_not_receive(:Principal).with(subject)
          manager.principals
        end

        it "clears the cache if current_subjects is set" do
          manager.principals
          AccessControl.stub(:Principal).with(subject).and_return(principal)
          manager.current_subjects = [subject]
          manager.principals.map(&:id).should include_only(principal.id)
        end

      end

    end

    describe "#can?" do

      let(:global_node) { stub('Global node') }
      let(:nodes)       { stub("Nodes collection") }
      let(:inspector)   { stub("Inspector", :permissions => permissions) }
      let(:permissions) { Set[stub("p1"), stub("p2")] }
      let(:inspector_at_global_node) do
        stub('Inspector', :permissions => Set.new)
      end

      before do
        manager.current_principals = [principal]

        AccessControl.stub(:global_node).and_return(global_node)
        PermissionInspector.stub(:new).with(nodes, [principal])
          .and_return(inspector)
        PermissionInspector.stub(:new).with(global_node, [principal])
          .and_return(inspector_at_global_node)
      end

      context "when given a single permission" do
        it "returns true if the nodes grant the permission" do
          permission = permissions.first
          return_value = manager.can?(permission, nodes)
          return_value.should be_true
        end

        it "returns false if the nodes don't grant the permission" do
          permission = stub
          return_value = manager.can?(permission, nodes)
          return_value.should be_false
        end
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

      context "when inside a 'trusted' block" do
        it "returns true without further verification" do
          manager.trust do
            manager.can?('anything', 'anywhere').should be_true
          end
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
        manager.current_principals = [principal]

        inspector.stub(:permissions   => permissions)
        inspector.stub(:current_roles => current_roles)
        AccessControl.stub(:global_node).and_return(global_node)

        PermissionInspector.stub(:new).with(nodes, [principal])
          .and_return(inspector)
        PermissionInspector.stub(:new).with(global_node, [principal])
          .and_return(inspector_at_global_node)
      end

      context "when the user has the permissions" do
        it "doesn't raise the 'Unauthorized' exception" do
          lambda {
            manager.can!(permissions, nodes)
          }.should_not raise_exception(::AccessControl::Unauthorized)
        end
      end

      context "when the user doesn't have the permissions" do
        let(:logger) { stub('Logger', :unauthorized => nil) }
        let(:missing_permissions) { Set["p4", "p5"] }

        before do
          AccessControl.stub(:logger).and_return(logger)
          manager.current_principals = [principal]
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
            nodes,
            [principal],
            instance_of(Array) # Backtrace
          ]

          logger.should_receive(:unauthorized).with(*log_arguments)

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

      describe "when restriction is on (default)" do
        it "executes a block without query restriction" do
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

      describe "when restriction is of (inside a without restricion block)" do
        it "executes a block without query restriction" do
          manager.without_query_restriction do
            manager.without_query_restriction do
              manager.restrict_queries?.should be_false
            end
          end
        end

        it "unrestricts queries after the block is run" do
          manager.without_query_restriction do
            manager.without_query_restriction {}
            manager.restrict_queries?.should be_false
          end
        end

        it "restricts queries even if the block raises an exception" do
          manager.without_query_restriction do
            manager.without_query_restriction {
              raise StandardError
            } rescue nil
            manager.restrict_queries?.should be_false
          end
        end

        it "raises any exception the block have raised" do
          exception = Class.new(StandardError)
          manager.without_query_restriction do
            lambda {
              manager.without_query_restriction { raise exception }
            }.should raise_exception(exception)
          end
        end

        it "returns the value returned by the block" do
          manager.without_query_restriction do
            manager.without_query_restriction{'a value returned by the block'}.
              should == 'a value returned by the block'
          end
        end
      end
    end

    describe "#trust" do
      before do
        manager.stub(:use_anonymous?).and_return(true) # Simulate web request
      end

      context "when the query restrictions were previously enabled (default)" do
        it "calls the block it receives" do
          lambda {
            manager.trust { throw :block_called }
          }.should throw_symbol(:block_called)
        end

        it "disables them while inside the block" do
          manager.trust do
            manager.should_not be_restricting_queries
          end
        end

        it "restores them back afterwards" do
          manager.trust { }
          manager.should be_restricting_queries
        end
      end

      context "when the query restrictions were previously disabled" do
        it "calls the block it receives" do
          manager.without_query_restriction do
            lambda {
              manager.trust { throw :block_called }
            }.should throw_symbol(:block_called)
          end
        end

        it "maintain them disabled while inside the block" do
          manager.without_query_restriction do
            manager.trust do
              manager.should_not be_restricting_queries
            end
          end
        end

        it "don't enable them after exiting the block" do
          manager.without_query_restriction do
            manager.trust { }
            manager.should_not be_restricting_queries
          end
        end
      end

      it "doesn't rescue the exceptions the block raises" do
        my_exception = Class.new(Exception)
        lambda {
          manager.trust do
            raise my_exception
          end
        }.should raise_exception(my_exception)
      end

      it "restores the restrictions even if the block raises an Exception" do
        my_exception = Class.new(Exception)
        lambda {
          begin
            manager.trust { raise my_exception }
          rescue my_exception
          end
        }.should_not change(manager, :restrict_queries?)
      end

      it "restores the 'trust' status even if the block raises an Exception" do
        my_exception = Class.new(Exception)
        begin
          manager.trust { raise my_exception }
        rescue my_exception
        end

        manager.should_not be_inside_trusted_block
      end

      it "maintains the 'trust' status when called in a nested form" do
        manager.trust do
          manager.trust {}
          manager.should be_inside_trusted_block
        end
      end

      it "returns the value returned by the block" do
        block_return = stub("Block return value")
        return_value = manager.trust { block_return }

        block_return.should == return_value
      end
    end
  end
end
