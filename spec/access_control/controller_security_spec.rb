require 'spec_helper'
require 'access_control/controller_security'

module AccessControl

  describe AccessControl do
    it "enables controller security by default" do
      AccessControl.should be_controller_security_enabled
    end
  end

  describe ControllerSecurity do

    let(:base) { Class.new }
    let(:records_controller_class) { Class.new(base) }
    let(:records_controller) do
      records_controller_class.new
    end

    let(:params) { HashWithIndifferentAccess.new }

    before do
      records_controller.stub(:params).and_return(params)
      records_controller_class.stub(:name).and_return('RecordsController')
      base.class_eval do
        def self.before_filter *args, &block
          options = args.extract_options!
          action = (options[:only] || :some_action).to_sym
          @filters ||= {}
          @filters[action] ||= []
          if block_given?
            @filters[action] << block
          else
            method = args.first
            @filters[action] << Proc.new{|controller| controller.send(method)}
          end
        end
        def self.filters
          @filters || {}
        end
        def call_filters_for_some_action
          (self.class.filters[:some_action] || []).each{|b| b.call(self)}
        end
        def process block
          some_action(block)
        end
      end
      records_controller_class.class_eval do
        def self.filters
          @filters ||= {}
          keys = superclass.filters.keys | @filters.keys
          keys.inject({}) do |h, k|
            h[k] = (@filters[k] || []) + (superclass.filters[k] || [])
            h
          end
        end
        def some_action(block=nil)
          call_filters_for_some_action
          block.call if block
        end
      end
      base.send(:include, ControllerSecurity::InstanceMethods)
    end

    it "includes into ActionController::Base" do
      ActionController::Base.should include(ControllerSecurity::InstanceMethods)
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

    describe "request wrapping" do

      let(:manager) { mock('manager') }

      before do
        AccessControl.stub(:manager).and_return(manager)
        AccessControl.stub(:no_manager)
        manager.stub(:use_anonymous!)
        records_controller.class.stub(:action_protected?).and_return(true)
        params[:action] = 'some_action'
      end

      describe "before action is executed" do

        it "makes the manager to use anonymous user by default" do
          manager.should_receive(:use_anonymous!).ordered
          manager.should_receive(:block_called).ordered
          records_controller.process(Proc.new{ manager.block_called })
        end

        it "checks if the action is protected" do
          records_controller.class.should_receive(:action_protected?).
            with('some_action'.to_sym).ordered
          records_controller.class.should_receive(:block_called).ordered
          records_controller.some_action(Proc.new{
            records_controller.class.block_called
          })
        end

        describe "when the action is not protected" do
          it "raises an error" do
            records_controller.class.stub(:action_protected?).and_return(false)
            lambda {
              records_controller.some_action
            }.should raise_error(AccessControl::MissingPermissionDeclaration)
          end
        end

      end

      describe "after action is executed" do

        it "unsets manager" do
          AccessControl.should_receive(:block_called).ordered
          AccessControl.should_receive(:no_manager).ordered
          records_controller.process(Proc.new{ AccessControl.block_called })
        end

        it "clears the global node cache" do
          AccessControl::Node.should_receive(:block_called).ordered
          AccessControl::Node.should_receive(:clear_global_node_cache).ordered
          records_controller.process(
            Proc.new{ AccessControl::Node.block_called }
          )
        end

        it "clears the anonymous principal cache" do
          AccessControl::Principal.should_receive(:block_called).ordered
          AccessControl::Principal.
            should_receive(:clear_anonymous_principal_cache).ordered
          records_controller.process(
            Proc.new{ AccessControl::Principal.block_called }
          )
        end

      end

    end

    describe "#current_context" do

      # This method should return one node for permission checking.  The
      # default behaviour can vary if the user is accessing a single resource
      # action or a collection action.  Currently, this is checked by the name
      # of the action.  For special needs, there's the option :context in the
      # `protect` method, which will allow customization of the security
      # context, allowing even to return more than one context, in an array.

      let(:records_controller_class) { Class.new(ActionController::Base) }
      before do
        records_controller_class.stub(:name).and_return('RecordsController')
      end

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
              it "returns the var" do
                records_controller.
                  send(:current_context).should == record
              end
            end

            describe "when there's a global node" do
              before do
                AccessControl::Node.stub(:global).and_return('the global node')
              end
              it "doesn't matter, returns the var" do
                records_controller.
                  send(:current_context).should == record
              end
            end

          end

          describe "when there's no instance var named according resource" do

            describe "and there's a global node" do
              before do
                AccessControl::Node.stub(:global).and_return('the global node')
              end
              it "returns it" do
                records_controller.send(:current_context).
                  should == 'the global node'
              end
            end

            describe "and there's no global node" do
              before do
                AccessControl::Node.stub(:global).and_return(nil)
              end
              it "returns nil, and probably will break some code" do
                records_controller.send(:current_context).should be_nil
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
                it "returns the var" do
                  records_controller.
                    send(:current_context).should == some_resource
                end
              end

              describe "and there's a global node" do
                before do
                  AccessControl::Node.stub(:global).
                    and_return('the global node')
                end
                it "doesn't matter, returns the var" do
                  records_controller.
                    send(:current_context).should == some_resource
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
                  records_controller.send(:current_context).
                    should == 'the global node'
                end
              end

              describe "and there's no global node" do
                before do
                  AccessControl::Node.stub(:global).and_return(nil)
                end
                it "returns nil, and probably will break some code" do
                  records_controller.send(:current_context).should be_nil
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
                records_controller.send(:current_context).
                  should == 'the global node'
              end
            end

            describe "and there's no global node" do
              before do
                AccessControl::Node.stub(:global).and_return(nil)
              end
              it "returns nil, and probably will break some code" do
                records_controller.send(:current_context).should be_nil
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
            records_controller.send(:current_context).should == \
              'the global node'
          end
        end

        describe "when there's no global node" do
          before do
            AccessControl::Node.stub(:global).and_return(nil)
          end
          it "returns nil, and probably will break some code" do
            records_controller.send(:current_context).should be_nil
          end
        end

      end

      it "is declared private" do
        # This should not be public since it is not an action.
        records_controller.private_methods.should(
          include('current_context')
        )
      end

    end

    describe "action protection" do

      let(:manager) { mock('manager') }
      let(:node) { stub('node') }

      before do
        Registry.stub(:register)
        AccessControl.stub(:manager).and_return(manager)
        records_controller.stub(:current_context).and_return(node)
        manager.stub(:can!)
        params[:action] = 'some_action'
      end

      it "raises an error when there's no context" do
        records_controller.should_receive(:current_context).
          and_return(nil)
        records_controller.class.class_eval do
          protect :some_action, :with => 'some permission'
        end
        lambda {
          records_controller.some_action
        }.should raise_exception(::AccessControl::NoContextError)
      end

      it "works when `current_context` is protected" do
        records_controller.class.class_eval do
          protected :current_context
          protect :some_action, :with => 'some permission'
        end
        lambda {
          records_controller.some_action
        }.should_not raise_exception
      end

      it "works when `current_context` is private" do
        records_controller.class.class_eval do
          private :current_context
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
        manager.should_receive(:can!).
          with(Set.new(['some permission']), 'a custom context')
        records_controller.some_action
      end

      it "accepts a proc as a custom context" do
        records_controller.class.class_eval do
          protect :some_action,
                  :with => 'some permission',
                  :context => Proc.new{|controller| 'a custom context'}
        end
        manager.should_receive(:can!).
          with(Set.new(['some permission']), 'a custom context')
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
        manager.should_receive(:can!).
          with(Set.new(['some permission']), 'a custom context')
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
        manager.should_receive(:can!).
          with(Set.new(['some permission']), 'a custom context')
        records_controller.some_action
      end

      it "raises unauthorized if action is accessed without permission" do
        records_controller.class.class_eval do
          protect :some_action, :with => 'some permission'
        end
        manager.stub!(:can!).and_raise('the unauthorized exception')
        lambda {
          records_controller.some_action
        }.should raise_exception('the unauthorized exception')
      end

      it "doesn't raise unauthorized if security is disabled" do
        records_controller.class.class_eval do
          protect :some_action, :with => 'some permission'
        end
        AccessControl.stub!(:controller_security_enabled?).and_return(false)
        manager.stub!(:can!).and_raise('the unauthorized exception')
        records_controller.some_action
      end

      it "registers the permissions passed in :with and additional metadata" do
        Registry.should_receive(:register).
          with(Set.new(['the content of the :with option']),
               :metadata => 'value')
        records_controller.class.class_eval do
          protect :some_action, :with => 'the content of the :with option',
                  :data => { :metadata => 'value' }, :ignored => 'ignored'
        end
      end

      it "marks the action as protected" do
        records_controller.class.class_eval do
          protect :some_action, :with => 'the content of the :with option'
        end
        records_controller.class.action_protected?(:some_action).should be_true
      end

      describe "with string permission" do
        it "protects an action with permissions provided" do
          manager.should_receive(:can!).
            with(Set.new(['some permission']), node)
          records_controller.class.class_eval do
            protect :some_action, :with => 'some permission'
          end
          records_controller.some_action
        end
      end

      describe "with array of permissions" do
        it "protects an action with permissions provided" do
          manager.should_receive(:can!).
            with(Set.new(['some permission']), node)
          records_controller.class.class_eval do
            protect :some_action, :with => ['some permission']
          end
          records_controller.some_action
        end
      end

      describe "with set of permissions" do
        it "protects an action with permissions provided" do
          manager.should_receive(:can!).
            with(Set.new(['some permission']), node)
          records_controller.class.class_eval do
            protect :some_action, :with => Set.new(['some permission'])
          end
          records_controller.some_action
        end
      end

      describe "with AccessControl::PUBLIC" do

        it "doesn't protects the action at all" do
          manager.should_not_receive(:can!)
          records_controller.class.class_eval do
            protect :some_action, :with => PUBLIC
          end
          records_controller.some_action
        end

        it "doesn't registers permission" do
          Registry.should_not_receive(:register)
          records_controller.class.class_eval do
            protect :some_action, :with => PUBLIC
          end
        end

        describe "if PUBLIC isn't passed alone" do

          it "raises error" do
            lambda {
              records_controller.class.class_eval do
                protect :some_action, :with => [PUBLIC, 'some permission']
              end
            }.should raise_exception(ArgumentError)
          end

          it "doesn't mark action as protected" do
            records_controller.class.class_eval do
              protect :some_action, :with => [PUBLIC, 'some permission'] \
                rescue nil
            end
            records_controller.class.action_protected?(:some_action).
              should be_false
          end

        end
      end

    end

    describe "action publication" do
      it "calls protect with AccessControl::PUBLIC" do
        records_controller.class.should_receive(:protect).
          with(:some_action, :with => AccessControl::PUBLIC)
        records_controller.class.publish :some_action
      end
    end

  end
end
