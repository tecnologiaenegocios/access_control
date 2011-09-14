require 'spec_helper'
require 'access_control/controller_security'

module AccessControl

  describe AccessControl do
    it "enables controller security by default" do
      AccessControl.should be_controller_security_enabled
    end
  end

  describe ControllerSecurity do

    let(:base) do
      Class.new(ActionController::Base) do
        def process_without_filters(req, resp, method=:perform_action, *args)
          perform_the_action
        end
        def perform_the_action
          chain = self.class.filter_chain
          index = run_before_filters(chain, 0, 0)
          send(action_name) unless @before_filter_chain_aborted
          run_after_filters(chain, index)
        end
        def process_with_block(&block)
          @action_block = block
          process_without_block(nil, nil)
        end
        alias_method :process_without_block, :process
        alias_method :process, :process_with_block
        def action_name
          'some_action'
        end
      end
    end
    let(:records_controller_class) { Class.new(base) }
    let(:records_controller) do
      records_controller_class.new
    end
    let(:params) { HashWithIndifferentAccess.new }
    let(:manager) { mock('manager') }

    before do
      records_controller.stub(:params).and_return(params)
      records_controller_class.stub(:name).and_return('RecordsController')
      records_controller_class.class_eval do
        def some_action
          @action_block.call if @action_block
        end
      end
      params[:action] = 'some_action'
      manager.stub(:can!)
      manager.stub(:use_anonymous!)
      AccessControl.stub(:manager).and_return(manager)
      AccessControl.stub(:no_manager)
      AccessControl::PublicActions.clear
    end

    describe ".protect" do

      it "registers permissions with __ac_controller__ and __ac_action__" do
        Registry.should_receive(:register).with(
          Set.new(['the contents of the :with option']),
          :__ac_controller__ => 'RecordsController',
          :__ac_action__ => :some_action,
          :__ac_context__ => :current_context
        )
        records_controller.class.
          protect :some_action, :with => 'the contents of the :with option'
      end

      it "registers additional metadata under :data option" do
        Registry.should_receive(:register).with(
          Set.new(['the contents of the :with option']),
          :metadata => 'value',
          :__ac_controller__ => 'RecordsController',
          :__ac_action__ => :some_action,
          :__ac_context__ => :current_context
        )
        records_controller.class.protect(
          :some_action,
          :with => 'the contents of the :with option',
          :data => { :metadata => 'value' }
        )
      end

      it "doesn't register values outside :data option" do
        Registry.should_receive(:register).with(
          Set.new(['the contents of the :with option']),
          :metadata => 'value',
          :__ac_controller__ => 'RecordsController',
          :__ac_action__ => :some_action,
          :__ac_context__ => :current_context
        )
        records_controller.class.protect(
          :some_action,
          :with => 'the contents of the :with option',
          :data => { :metadata => 'value' },
          :ignored => 'ignored'
        )
      end

      it "accepts multiple permissions as an array" do
        Registry.should_receive(:register).with(
          Set.new(['permission 1', 'permission 2']), instance_of(Hash)
        )
        records_controller.class.
          protect(:some_action, :with => ['permission 1', 'permission 2'])
      end

      it "accepts multiple permissions as an set" do
        Registry.should_receive(:register).with(
          Set.new(['permission 1', 'permission 2']), instance_of(Hash)
        )
        records_controller.class.protect(
          :some_action,
          :with => Set.new(['permission 1', 'permission 2'])
        )
      end

      describe ":context" do

        it "overrides the default value of __ac_context__ metadata" do
          context = stub('the contents of the context option')
          Registry.should_receive(:register).with(
            Set.new(['the contents of the :with option']),
            :__ac_controller__ => 'RecordsController',
            :__ac_action__ => :some_action,
            :__ac_context__ => context
          )
          records_controller.class.protect(
            :some_action,
            :with => 'the contents of the :with option',
            :context => context
          )
        end

      end

      it "doesn't mark the action as public" do
        records_controller.class.
          protect :some_action, :with => 'the content of the :with option'
        records_controller.class.action_public?(:some_action).
          should be_false
      end

      describe "with AccessControl::PUBLIC" do

        it "marks the action as public" do
          records_controller.class.protect :some_action, :with => PUBLIC
          records_controller.class.action_public?(:some_action).
            should be_true
        end

        describe "if PUBLIC isn't passed alone" do

          it "raises error" do
            lambda {
              records_controller.class.
                protect :some_action, :with => [PUBLIC, 'some permission']
            }.should raise_exception(ArgumentError)
          end

          it "doesn't mark action as public" do
            records_controller.class.
              protect :some_action, :with => [PUBLIC, 'some permission'] \
                rescue nil
            records_controller.class.action_public?(:some_action).
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

    describe "request wrapping" do

      let(:node) { stub('node') }
      let(:default_context) { :current_context }

      before do
        Registry.stub(:register)
        Registry.stub(:query).and_return(Set.new(['some permission']))
        Registry.stub(:all_with_metadata).and_return({
          'some permission' => Set.new([{
            :__ac_controller__ => 'RecordsController',
            :__ac_action__     => :some_action,
            :__ac_context__    => default_context
          }, {:some_other_metadata => 'some other value'}])
        })
        records_controller.stub(:current_context).and_return(node)
        params[:action] = 'some_action'
      end

      describe "before action is executed" do

        it "makes the manager to use anonymous user by default" do
          manager.should_receive(:use_anonymous!).ordered
          manager.should_receive(:block_called).ordered
          records_controller.process { manager.block_called }
        end

        it "checks if the action is public" do
          records_controller.class.should_receive(:action_public?).
            with('some_action').ordered
          records_controller.class.should_receive(:block_called).ordered
          records_controller.process do
            records_controller.class.block_called
          end
        end

        describe "when the action is not protected" do
          it "doesn't call manager.can!" do
            records_controller.class.stub(:action_public?).and_return(true)
            manager.should_not_receive(:can!)
            records_controller.process
          end
        end

        describe "when the action is not public" do

          before do
            records_controller.class.stub(:action_public?).and_return(false)
          end

          it "queries the Registry for a permission matching the controller "\
             "and action" do
            Registry.should_receive(:query).with(
              :__ac_controller__ => 'RecordsController',
              :__ac_action__ => :some_action
            ).and_return(Set.new(['some permission']))
            records_controller.process
          end

          describe "when no permission is returned" do
            it "complains" do
              Registry.stub(:query).and_return(Set.new)
              lambda { records_controller.process }.should(
                raise_exception(AccessControl::MissingPermissionDeclaration)
              )
            end
          end

          describe "for each permission returned in Registry.query" do

            describe ":__ac_context__" do

              describe "is a symbol which is the name of a method" do

                let(:default_context) { :custom_context }

                before do
                  records_controller.stub(:custom_context => 'a custom context')
                end

                it "calls the method" do
                  records_controller.should_receive(:custom_context).
                    and_return('custom context')
                  records_controller.process
                end

                it "checks permission using the return value of the method" do
                  manager.should_receive(:can!).
                    with('some permission', 'a custom context')
                  records_controller.process
                end

                it "raises error when there's no context" do
                  records_controller.stub(:custom_context => nil)
                  lambda {
                    records_controller.process
                  }.should raise_exception(AccessControl::NoContextError)
                end

              end

              describe "is a symbol stating with @" do

                let(:default_context) { :@var_name }

                before do
                  records_controller.instance_variable_set('@var_name',
                                                           'a custom context')
                end

                it "checks permission using the variable value as context" do
                  manager.should_receive(:can!).
                    with('some permission', 'a custom context')
                  records_controller.process
                end

                it "raises error when there's no context" do
                  records_controller.instance_variable_set('@var_name', nil)
                  lambda {
                    records_controller.process
                  }.should raise_exception(AccessControl::NoContextError)
                end

              end

              describe "is a Proc" do

                let(:default_context) do
                  Proc.new{|controller| controller.custom_context }
                end

                before do
                  records_controller.stub(:custom_context).
                    and_return('a custom context')
                end

                it "checks permission using the return value of the proc" do
                  manager.should_receive(:can!).
                    with('some permission', 'a custom context')
                  records_controller.process
                end

                it "raises error when there's no context" do
                  records_controller.stub(:custom_context => nil)
                  lambda {
                    records_controller.process
                  }.should raise_exception(AccessControl::NoContextError)
                end

              end

            end

            it "doesn't test permission if security is disabled" do
              AccessControl.stub(:controller_security_enabled?).
                and_return(false)
              manager.should_not_receive(:can!)
              records_controller.process
            end

          end

        end

      end

      describe "after action is executed" do

        it "unsets manager" do
          AccessControl.should_receive(:block_called).ordered
          AccessControl.should_receive(:no_manager).ordered
          records_controller.process { AccessControl.block_called }
        end

        it "clears the global node cache" do
          AccessControl::Node.should_receive(:block_called).ordered
          AccessControl::Node.should_receive(:clear_global_node_cache).ordered
          records_controller.process do
            AccessControl::Node.block_called
          end
        end

        it "clears the anonymous principal cache" do
          AccessControl::Principal.should_receive(:block_called).ordered
          AccessControl::Principal.
            should_receive(:clear_anonymous_principal_cache).ordered
          records_controller.process do
            AccessControl::Principal.block_called
          end
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

  end
end
