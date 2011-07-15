require 'spec_helper'
require 'access_control/controller_security'

module AccessControl

  describe AccessControl do
    it "enables controller security by default" do
      AccessControl.should be_controller_security_enabled
    end
  end

  describe ControllerSecurity do

    let(:records_controller) do
      RecordsController.new
    end

    let(:params) { HashWithIndifferentAccess.new }

    before do
      class ActionController::Base
        include ControllerSecurity::InstanceMethods
      end
      class ::Object::RecordsController < ActionController::Base
      end
      ActiveRecord::Base.stub!(:drop_all_temporary_instantiation_requirements!)
      records_controller.stub!(:params).and_return(params)
      records_controller.stub(:current_user)
    end

    after do
      Object.send(:remove_const, 'RecordsController')
    end

    describe "#current_groups" do

      # There must be by default an implementation of `current_groups` that is
      # private and returns an empty array.  This simplifies the common case
      # where there's no concept of user groups.

      it "returns an empty array" do
        records_controller.send(:current_groups).should == []
      end

      it "is declared private" do
        records_controller.private_methods.should include('current_groups')
      end
    end

    describe "#security_manager" do

      it "returns the current security manager" do
        manager = stub('manager')
        AccessControl.should_receive(:security_manager).and_return(manager)
        records_controller.security_manager.should == manager
      end

    end

    describe "request wrapping with a security manager available" do

      let(:manager) { SecurityManager.new }

      before do
        AccessControl.stub(:security_manager).and_return(manager)
        RecordsController.class_eval do
          # This method overrides the default implementation of `process` from
          # Rails, which was aliased.
          def process_without_security_manager block
            block.call
          end
        end
      end

      describe "before action is executed" do

        it "feeds the security manager with the current user" do
          records_controller.should_receive(:current_user).
            and_return('the current user')
          manager.should_receive(:current_user=).with('the current user')
          records_controller.process(Proc.new{})
        end

        it "feeds the security manager with the current groups" do
          records_controller.should_receive(:current_groups).
            and_return('the current groups')
          manager.should_receive(:current_groups=).with('the current groups')
          records_controller.process(Proc.new{})
        end

        it "executes the action afterwards" do
          user = stub('user')
          groups = stub('groups')
          records_controller.stub(:current_user => user)
          records_controller.stub(:current_groups => groups)
          records_controller.process(lambda {
            AccessControl.security_manager.current_user.should == user
            AccessControl.security_manager.current_groups.should == groups
          })
        end

      end

      describe "after action is executed" do

        it "unsets security manager after action execution" do
          AccessControl.should_receive(:no_security_manager)
          records_controller.process(Proc.new{})
        end

        it "clears the global node cache after action execution" do
          AccessControl::Node.should_receive(:clear_global_node_cache)
          records_controller.process(Proc.new{})
        end

        it "drops all temp instantiation requirements after action execution" do
          ActiveRecord::Base.
            should_receive(:drop_all_temporary_instantiation_requirements!)
          records_controller.process(Proc.new{})
        end

      end

    end

    describe "#current_security_context" do

      # This method should return one node for permission checking.  The
      # default behaviour can vary if the user is accessing a single resource
      # action or a collection action.  Currently, this is checked by the name
      # of the action.  For special needs, there's the option :context in the
      # `protect` method, which will allow customization of the security
      # context, allowing even to return more than one context, in an array.

      %w(show edit update destroy).each do |action|

        describe "for action #{action}" do

          before do
            params[:action] = action
          end

          describe "when there's an instance var named according resource" do

            let(:record) { mock('test resource') }

            before do
              records_controller.instance_variable_set('@record', record)
            end

            describe "when there's no global node" do
              it "returns the var's ac_node" do
                record.should_receive(:ac_node).
                  and_return('the ac_node of record')
                records_controller.send(:current_security_context).
                  should == 'the ac_node of record'
              end
            end

            describe "when there's a global node" do
              before do
                AccessControl::Node.stub(:global).and_return('the global node')
              end
              it "doesn't matter, returns the var's ac_node" do
                record.should_receive(:ac_node).
                  and_return('the ac_node of record')
                records_controller.send(:current_security_context).
                  should == 'the ac_node of record'
              end
            end

          end

          describe "when there's no instance var named according resource" do

            describe "and there's a global node" do
              before do
                AccessControl::Node.stub(:global).and_return('the global node')
              end
              it "returns it" do
                records_controller.send(:current_security_context).
                  should == 'the global node'
              end
            end

            describe "and there's no global node" do
              before do
                AccessControl::Node.stub(:global).and_return(nil)
              end
              it "returns nil, and probably will break some code" do
                records_controller.send(:current_security_context).should be_nil
              end
            end

          end

        end

      end

      %w(index new create).each do |action|

        describe "for action #{action}" do

          before do
            params[:action] = action
          end

          describe "when there's a parent resource" do

            before do
              params[:some_resource_id] = 'a resource id'
              ActionController::Routing::Routes.draw do |map|
                map.resources :some_resources do |parent|
                  parent.resources :records
                end
              end
            end

            describe "and an instance var named accondingly" do

              let(:some_resource) { mock('the parent resource') }

              before do
                records_controller.instance_variable_set('@some_resource',
                                                         some_resource)
              end

              describe "and there's no global node" do
                it "returns the var's ac_node" do
                  some_resource.should_receive(:ac_node).
                    and_return("the parent's ac_node")
                  records_controller.send(:current_security_context).
                    should == "the parent's ac_node"
                end
              end

              describe "and there's a global node" do
                before do
                  AccessControl::Node.stub(:global).
                    and_return('the global node')
                end
                it "doesn't matter, returns the var's ac_node" do
                  some_resource.should_receive(:ac_node).
                    and_return("the parent's ac_node")
                  records_controller.send(:current_security_context).
                    should == "the parent's ac_node"
                end
              end

            end

            describe "and there's no var named accordingly" do

              describe "and there's a global node" do
                before do
                  AccessControl::Node.stub(:global).
                    and_return('the global node')
                end
                it "returns it" do
                  records_controller.send(:current_security_context).
                    should == 'the global node'
                end
              end

              describe "and there's no global node" do
                before do
                  AccessControl::Node.stub(:global).and_return(nil)
                end
                it "returns nil, and probably will break some code" do
                  records_controller.send(:current_security_context).should be_nil
                end
              end

            end

          end

          describe "and there's no parent resource parameter" do

            describe "and there's a global node" do
              before do
                AccessControl::Node.stub(:global).and_return('the global node')
              end
              it "returns it" do
                records_controller.send(:current_security_context).
                  should == 'the global node'
              end
            end

            describe "and there's no global node" do
              before do
                AccessControl::Node.stub(:global).and_return(nil)
              end
              it "returns nil, and probably will break some code" do
                records_controller.send(:current_security_context).should be_nil
              end
            end

          end

        end

      end

      describe "for any other action" do

        before do
          params[:action] = 'some_custom_action'
        end

        describe "when there's a global node" do
          before do
            AccessControl::Node.stub(:global).and_return('the global node')
          end
          it "falls back into the global node" do
          end
        end

        describe "when there's no global node" do
          before do
            AccessControl::Node.stub(:global).and_return(nil)
          end
          it "returns nil, and probably will break some code" do
            records_controller.send(:current_security_context).should be_nil
          end
        end

      end

      it "is declared private" do
        # This should not be public since it is not an action.
        records_controller.private_methods.should(
          include('current_security_context')
        )
      end

    end

    describe "action protection" do

      let(:manager) { mock('manager') }
      let(:node) { stub('node') }

      before do
        records_controller.class.instance_eval do
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
        records_controller.class.class_eval do
          def call_filters_for_some_action
            self.class.filters[:some_action].each{|b| b.call(self)}
          end
          def some_action
            call_filters_for_some_action
          end
        end
        PermissionRegistry.stub(:register)
        records_controller.stub(:current_security_context).and_return(node)
        AccessControl.stub(:security_manager).and_return(manager)
        manager.stub(:verify_access!)
      end

      it "raises an error when there's no security context" do
        records_controller.should_receive(:current_security_context).
          and_return(nil)
        records_controller.class.class_eval do
          protect :some_action, :with => 'some permission'
        end
        lambda {
          records_controller.some_action
        }.should raise_exception(::AccessControl::NoSecurityContextError)
      end

      it "works when `current_security_context` is protected" do
        records_controller.class.class_eval do
          protected :current_security_context
          protect :some_action, :with => 'some permission'
        end
        lambda {
          records_controller.some_action
        }.should_not raise_exception
      end

      it "works when `current_security_context` is private" do
        records_controller.class.class_eval do
          private :current_security_context
          protect :some_action, :with => 'some permission'
        end
        lambda {
          records_controller.some_action
        }.should_not raise_exception
      end

      it "accepts a custom context as symbol that is the name of a method" do
        records_controller.class.class_eval do
          protect :some_action,
                  :with => 'some permission',
                  :context => :custom_context
          def custom_context
            'a custom context'
          end
        end
        manager.should_receive(:verify_access!).
          with('a custom context', Set.new(['some permission']))
        records_controller.some_action
      end

      it "accepts a proc as a custom context" do
        records_controller.class.class_eval do
          protect :some_action,
                  :with => 'some permission',
                  :context => Proc.new{|controller| 'a custom context'}
        end
        manager.should_receive(:verify_access!).
          with('a custom context', Set.new(['some permission']))
        records_controller.some_action
      end

      it "accepts a symbol starting with @ to indicate an instance var as "\
         "the context" do
        records_controller.class.class_eval do
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
        records_controller.some_action
      end

      it "passes the controller instance to the proc for context" do
        records_controller.class.class_eval do
          protect :some_action,
                  :with => 'some permission',
                  :context => Proc.new{|controller| controller.custom_context}
          def custom_context
            'a custom context'
          end
        end
        manager.should_receive(:verify_access!).
          with('a custom context', Set.new(['some permission']))
        records_controller.some_action
      end

      it "raises unauthorized if action is accessed without permission" do
        records_controller.class.class_eval do
          protect :some_action, :with => 'some permission'
        end
        manager.stub!(:verify_access!).and_raise('the unauthorized exception')
        lambda {
          records_controller.some_action
        }.should raise_exception('the unauthorized exception')
      end

      it "doesn't raise unauthorized if security is disabled" do
        records_controller.class.class_eval do
          protect :some_action, :with => 'some permission'
        end
        AccessControl.stub!(:controller_security_enabled?).and_return(false)
        manager.stub!(:verify_access!).and_raise('the unauthorized exception')
        records_controller.some_action
      end

      it "registers the permissions passed in :with and additional options" do
        PermissionRegistry.should_receive(:register).
          with('the content of the :with option',
               :controller => 'RecordsController',
               :action => 'some_action')
        records_controller.class.class_eval do
          protect :some_action, :with => 'the content of the :with option'
        end
      end

      describe "with string permission" do
        it "protects an action with permissions provided" do
          manager.should_receive(:verify_access!).
            with(node, Set.new(['some permission']))
          records_controller.class.class_eval do
            protect :some_action, :with => 'some permission'
          end
          records_controller.some_action
        end
      end

      describe "with array of permissions" do
        it "protects an action with permissions provided" do
          manager.should_receive(:verify_access!).
            with(node, Set.new(['some permission']))
          records_controller.class.class_eval do
            protect :some_action, :with => ['some permission']
          end
          records_controller.some_action
        end
      end

      describe "with set of permissions" do
        it "protects an action with permissions provided" do
          manager.should_receive(:verify_access!).
            with(node, Set.new(['some permission']))
          records_controller.class.class_eval do
            protect :some_action, :with => Set.new(['some permission'])
          end
          records_controller.some_action
        end
      end

      describe "instantiation protection" do

        before do
          class Object::Record < ActiveRecord::Base
          end
        end

        after do
          Object.send(:remove_const, 'Record')
        end

        it "protects a model from being instantiated" do
          records_controller.class.class_eval do
            protect :some_action,
                    :with => 'some permission',
                    :when_instantiating => 'Record',
                    :context => :context_method
            def some_action
              call_filters_for_some_action
              Record.new('the args for a new test model')
            end
            def context_method
              'some context'
            end
          end
          Record.should_receive(:set_temporary_instantiation_requirement).
            with('some context', Set.new(['some permission']))
          Record.should_receive(:new).with('the args for a new test model')
          records_controller.some_action
        end

      end

    end

  end
end
