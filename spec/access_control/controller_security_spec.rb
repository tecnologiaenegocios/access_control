require 'spec_helper'
require 'access_control/controller_security'

module AccessControl

  describe AccessControl do
    it "enables controller security by default" do
      AccessControl.should be_controller_security_enabled
    end
  end

  describe ControllerSecurity do

    let(:test_controller) do
      TestController.new
    end

    before do
      class ActionController::Base
        include ControllerSecurity::InstanceMethods
      end
      class ::Object::TestController < ActionController::Base
      end
      ActiveRecord::Base.stub!(:drop_all_temporary_instantiation_requirements!)
    end

    after do
      Object.send(:remove_const, 'TestController')
    end

    describe "#current_groups" do

      # There must be by default an implementation of `current_groups` that is
      # private and returns an empty array.  This simplifies the common case
      # where there's no concept of user groups.

      it "returns an empty array" do
        test_controller.send(:current_groups).should == []
      end

      it "is declared private" do
        test_controller.private_methods.should include('current_groups')
      end
    end

    describe "#security_manager" do

      it "returns the current security manager" do
        manager = stub('manager')
        AccessControl.should_receive(:security_manager).and_return(manager)
        test_controller.security_manager.should == manager
      end

    end

    describe "request wrapping with a security manager available" do

      let(:manager) {mock('manager')}

      before do
        AccessControl::SecurityManager.stub!(:new).
          with(test_controller).and_return(manager)
        TestController.class_eval do
          # This method overrides the default implementation of `process` from
          # Rails, which was aliased.
          def process_without_security_manager block
            block.call
          end
        end
      end

      it "provides a security manager during action execution" do
        test_controller.process(Proc.new do
          AccessControl.security_manager.should == manager
        end)
      end

      it "unsets security manager after action execution" do
        test_controller.process(Proc.new{})
        AccessControl.security_manager.should be_nil
      end

      it "clears the global cache after action execution" do
        AccessControl::Node.should_receive(:clear_global_node_cache)
        test_controller.process(Proc.new{})
      end

      it "drops all temp instantiation requirements after action execution" do
        ActiveRecord::Base.
          should_receive(:drop_all_temporary_instantiation_requirements!)
        test_controller.process(Proc.new{})
      end

    end

    describe "#current_security_context" do

      it "returns nil by default (no context)" do
        AccessControl::Node.clear_global_node_cache
        test_controller.send(:current_security_context).should be_nil
      end

      it "returns the global node if there is one" do
        AccessControl::Node.create_global_node!
        global = AccessControl::Node.global
        test_controller.send(:current_security_context).should == global
      end

      it "is declared private" do
        test_controller.private_methods.should(
          include('current_security_context')
        )
      end

    end

    describe "action protection" do

      let(:manager) { mock('manager') }
      let(:node) { stub('node') }

      before do
        test_controller.class.instance_eval do
          def before_filter *args, &block
            options = args.extract_options!
            action = options[:only].to_sym
            @filters ||= {}
            @filters[action] ||= []
            if block_given?
              @filters[action] << block
            else
              method = args.first
              @filters[action] << Proc.new{|controller| controller.send(method)}
            end
          end
          def filters
            @filters
          end
        end
        test_controller.class.class_eval do
          def call_filters_for_some_action
            self.class.filters[:some_action].each{|b| b.call(self)}
          end
          def some_action
            call_filters_for_some_action
          end
        end
        PermissionRegistry.stub!(:register)
        test_controller.stub!(:current_security_context).and_return(node)
        AccessControl.stub!(:security_manager).and_return(manager)
        manager.stub!(:verify_access!)
      end

      it "raises an error when there's no security context" do
        test_controller.should_receive(:current_security_context).
          and_return(nil)
        test_controller.class.class_eval do
          protect :some_action, :with => 'some permission'
        end
        lambda {
          test_controller.some_action
        }.should raise_exception(::AccessControl::NoSecurityContextError)
      end

      it "works when `current_security_context` is protected" do
        test_controller.class.class_eval do
          protected :current_security_context
          protect :some_action, :with => 'some permission'
        end
        lambda {
          test_controller.some_action
        }.should_not raise_exception
      end

      it "works when `current_security_context` is private" do
        test_controller.class.class_eval do
          private :current_security_context
          protect :some_action, :with => 'some permission'
        end
        lambda {
          test_controller.some_action
        }.should_not raise_exception
      end

      it "accepts a custom context as symbol that is the name of a method" do
        test_controller.class.class_eval do
          protect :some_action,
                  :with => 'some permission',
                  :context => :custom_context
          def custom_context
            'a custom context'
          end
        end
        manager.should_receive(:verify_access!).
          with('a custom context', Set.new(['some permission']))
        test_controller.some_action
      end

      it "accepts a proc as a custom context" do
        test_controller.class.class_eval do
          protect :some_action,
                  :with => 'some permission',
                  :context => Proc.new{|controller| 'a custom context'}
        end
        manager.should_receive(:verify_access!).
          with('a custom context', Set.new(['some permission']))
        test_controller.some_action
      end

      it "accepts a symbol starting with @ to indicate an instance var as "\
         "the context" do
        test_controller.class.class_eval do
          before_filter :load_variable, :only => :some_action
          protect :some_action,
                  :with => 'some permission',
                  :context => :@variable
          def load_variable
            @variable = 'a custom context'
          end
        end
        manager.should_receive(:verify_access!).
          with('a custom context', Set.new(['some permission']))
        test_controller.some_action
      end

      it "passes the controller instance to the proc for context" do
        test_controller.class.class_eval do
          protect :some_action,
                  :with => 'some permission',
                  :context => Proc.new{|controller| controller.custom_context}
          def custom_context
            'a custom context'
          end
        end
        manager.should_receive(:verify_access!).
          with('a custom context', Set.new(['some permission']))
        test_controller.some_action
      end

      it "raises unauthorized if action is accessed without permission" do
        test_controller.class.class_eval do
          protect :some_action, :with => 'some permission'
        end
        manager.stub!(:verify_access!).and_raise('the unauthorized exception')
        lambda {
          test_controller.some_action
        }.should raise_exception('the unauthorized exception')
      end

      it "doesn't raise unauthorized if security is disabled" do
        test_controller.class.class_eval do
          protect :some_action, :with => 'some permission'
        end
        AccessControl.stub!(:controller_security_enabled?).and_return(false)
        manager.stub!(:verify_access!).and_raise('the unauthorized exception')
        test_controller.some_action
      end

      it "registers the permissions passed in :with and additional options" do
        PermissionRegistry.should_receive(:register).
          with('the content of the :with option',
               :controller => 'TestController',
               :action => 'some_action')
        test_controller.class.class_eval do
          protect :some_action, :with => 'the content of the :with option'
        end
      end

      describe "with string permission" do
        it "protects an action with permissions provided" do
          manager.should_receive(:verify_access!).
            with(node, Set.new(['some permission']))
          test_controller.class.class_eval do
            protect :some_action, :with => 'some permission'
          end
          test_controller.some_action
        end
      end

      describe "with array of permissions" do
        it "protects an action with permissions provided" do
          manager.should_receive(:verify_access!).
            with(node, Set.new(['some permission']))
          test_controller.class.class_eval do
            protect :some_action, :with => ['some permission']
          end
          test_controller.some_action
        end
      end

      describe "with set of permissions" do
        it "protects an action with permissions provided" do
          manager.should_receive(:verify_access!).
            with(node, Set.new(['some permission']))
          test_controller.class.class_eval do
            protect :some_action, :with => Set.new(['some permission'])
          end
          test_controller.some_action
        end
      end

      describe "instantiation protection" do

        before do
          class Object::TestModel < ActiveRecord::Base
          end
        end

        after do
          Object.send(:remove_const, 'TestModel')
        end

        it "protects a model from being instantiated" do
          test_controller.class.class_eval do
            protect :some_action,
                    :with => 'some permission',
                    :when_instantiating => 'TestModel',
                    :context => :context_method
            def some_action
              call_filters_for_some_action
              TestModel.new('the args for a new test model')
            end
            def context_method
              'some context'
            end
          end
          TestModel.should_receive(:set_temporary_instantiation_requirement).
            with('some context', Set.new(['some permission']))
          TestModel.should_receive(:new).with('the args for a new test model')
          test_controller.some_action
        end

      end

    end

  end
end
