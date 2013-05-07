require 'spec_helper'
require 'access_control/controller_security'

module AccessControl

  describe ControllerSecurity do

    def make_app_controller
      base = Class.new(ActionController::Base) do
        def process_without_filters(req, resp, method=:perform_action, *args)
          perform_the_action
        end
        def perform_the_action
          chain = self.class.filter_chain
          index = run_before_filters(chain, 0, 0)
          send(action_name) unless @before_filter_chain_aborted
          run_after_filters(chain, index)
        end
        def process(&block)
          @action_block = block
          super(nil, nil)
        end
        def action_name
          'some_action'
        end
      end

      # Why ApplicationController1 and not ApplicationController?  Because our
      # spec/app/app/controllers folder already has one ApplicationController
      # constant.  And why don't we just use anonymous classes?  Because having
      # a name is a requirement for before_filters.
      Object.const_set('ApplicationController1', Class.new(base))

      ApplicationController1.class_eval do
        # before_filter :authenticate
        # The callback bellow must be placed after the authentication callback.
        before_filter :verify_permissions
      end
    end

    let(:records_controller_class) { Class.new(ApplicationController1) }
    let(:records_controller) do
      records_controller_class.new
    end
    let(:params) { HashWithIndifferentAccess.new }
    let(:manager) { mock('manager') }

    before do
      make_app_controller
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
      AccessControl::Node.stub(:clear_global_cache)
      AccessControl.stub(:manager).and_return(manager)
      AccessControl.stub(:no_manager)
      AccessControl::ControllerSecurity.published_actions.clear
      AccessControl::ControllerSecurity.protected_actions.clear
    end

    after do
      Object.send(:remove_const, 'ApplicationController1')
    end

    describe ".protect" do

      let(:registry)   { stub }
      let(:permission) { RegistryFactory::Permission.new }

      before do
        registry.stub(:permission).and_return(permission)
        registry.define_singleton_method(:store) do |permission_name, &block|
          permission.stub(:name).and_return(permission_name)
          block.call(permission)
        end

        AccessControl.stub(:registry).and_return(registry)
      end

      it "doesn't mark the action as public" do
        records_controller.class.
          protect :some_action, :with => 'the content of the :with option'
        records_controller.class.action_published?(:some_action).
          should be_false
      end

      it "marks the action as protected" do
        records_controller.class.action_protected?(:some_action).
          should be_false
        records_controller.class.
          protect :some_action, :with => 'the content of the :with option'
        records_controller.class.action_protected?(:some_action).should be_true
      end

      it "registers a permission" do
        records_controller.class.protect :some_action,
                                         :with => 'some_permission'
        permission.name.should == 'some_permission'
      end

      it "adds controller and action for the permission" do
        records_controller.class.protect 'some_action',
                                         :with => 'some_permission'
        permission.ac_methods.should ==
          Set.new([['RecordsController', :some_action]])
      end

      specify "more than one declaration for the same permission name "\
              "will accumulate controller and action tuples" do
        records_controller.class.protect :some_action,
                                         :with => 'some_permission'
        records_controller.class.protect :some_other_action,
                                         :with => 'some_permission'
        permission.ac_methods.should \
          include(['RecordsController', :some_action])
        permission.ac_methods.should \
          include(['RecordsController', :some_other_action])
      end

      context "when a context is given" do
        it "accepts a symbol as the context" do
          records_controller.class.protect :some_action,
                                           :with => 'some permission',
                                           :context => :some_method

          key = ['RecordsController', :some_action]
          permission.context_designator[key].should == :some_method
        end

        it "accepts a proc as the context" do
          context = Proc.new { }
          records_controller.class.protect :some_action,
                                           :with => 'some permission',
                                           :context => context

          key = ['RecordsController', :some_action]
          permission.context_designator[key].should be context
        end

        it "refuses something else" do
          lambda {
            records_controller.class.protect :some_action,
                                             :with => 'some permission',
                                             :context => 'something else'
          }.should raise_exception(InvalidContextDesignator)
        end
      end

      context "when a context is not given" do
        it "uses the default value `:current_context`" do
          records_controller.class.protect :some_action,
                                           :with => 'some permission'

          key = ['RecordsController', :some_action]
          permission.context_designator[key].should == :current_context
        end
      end

      context "when a block is given" do
        it "passes the permission to the block" do
          permission.should_receive(:block_called!)
          records_controller.class.protect :some_action,
                                           :with => 'some permission' do |p|
            p.block_called!
          end
        end
      end
    end

    describe ".unprotect" do
      # Use this method in tests in order to not carry state from a spec/test
      # to the next one.
      let(:registry)    { stub }
      let(:permission1) { RegistryFactory::Permission.new }
      let(:permission2) { RegistryFactory::Permission.new }

      before do
        permission1.stub(:name).and_return('some permission')
        permission2.stub(:name).and_return('some other permission')

        registry.stub(:store)
        registry.stub(:unstore)
        registry.stub(:query).and_return(Set.new)
        registry.stub(:query).
          with(:ac_methods => [[records_controller.class.name, :some_action]]).
          and_return(Set.new([permission1, permission2]))

        AccessControl.stub(:registry).and_return(registry)

        records_controller.class.protect :some_action,
                                         :with => 'some permission'
        records_controller.class.protect :some_action,
                                         :with => 'some other permission'
      end

      it "unmarks the action as protected" do
        records_controller.class.unprotect :some_action
        records_controller.class.action_protected?(:some_action).should be_false
      end

      it "unregisters the permissions associated with the action" do
        registry.should_receive(:unstore).with('some permission')
        registry.should_receive(:unstore).with('some other permission')
        records_controller.class.unprotect :some_action
      end
    end

    describe ".publish" do
      it "marks the action as public" do
        records_controller.class.publish :some_action
        records_controller.class.action_published?(:some_action).should be_true
      end
    end

    describe ".unpublish" do
      # Use this method in tests in order to not carry state from a spec/test
      # to the next one.
      it "unmarks the action as public" do
        records_controller.class.publish :some_action
        records_controller.class.unpublish :some_action
        records_controller.class.action_published?(:some_action).should be_false
      end
    end

    describe "ControllerSecurity.clear" do
      it "wipes out published actions" do
        records_controller.class.publish :some_action

        ControllerSecurity.clear
        records_controller.class.action_published?(:some_action).should be_false
      end

      it "wipes out protected actions" do
        registry = stub
        AccessControl.stub(:registry).and_return(registry)
        registry.stub(:store)
        records_controller.class.protect :some_action,
                                         :with => 'some permission'

        ControllerSecurity.clear
        records_controller.class.action_protected?(:some_action).should be_false
      end
    end

    describe "request wrapping" do

      let(:node)         { stub('node') }
      let(:test_context) { :current_context }
      let(:query_key)    { ['RecordsController', :some_action] }
      let(:permission)   { RegistryFactory::Permission.new('some_permission') }
      let(:registry)     { stub }

      before do
        records_controller.stub(:current_context).and_return(node)
        params[:action] = 'some_action'

        registry.stub(:register)
        registry.stub(:query).with(:ac_methods => [query_key]).
          and_return(Set.new([permission]))
        AccessControl.stub(:registry).and_return(registry)

        permission.context_designator[query_key] = test_context
        manager.stub(:can!)
      end

      describe "before action is executed" do

        it "makes the manager to use anonymous user by default" do
          manager.should_receive(:use_anonymous!).ordered
          manager.should_receive(:block_called).ordered
          records_controller.process { manager.block_called }
        end

        it "checks if the action is public" do
          records_controller.class.should_receive(:action_published?).
            with('some_action').ordered
          records_controller.class.should_receive(:block_called).ordered
          records_controller.process do
            records_controller.class.block_called
          end
        end

        describe "when the action is not protected" do
          it "doesn't call manager.can!" do
            records_controller.class.stub(:action_published?).and_return(true)
            manager.should_not_receive(:can!)
            records_controller.process
          end
        end

        describe "when the action is not public" do

          before do
            records_controller.class.stub(:action_published?).and_return(false)
          end

          context "when no permission is returned" do
            it "complains" do
              registry.stub(:query).and_return(Set.new)
              lambda { records_controller.process }.should(
                raise_exception(AccessControl::MissingPermissionDeclaration)
              )
            end
          end

          describe "for each permission returned in Registry.query" do

            context "when Permission#context_designator[query_key]" do

              context "is a symbol which is the name of a method" do

                let(:test_context) { :custom_context }

                before do
                  records_controller.stub(:custom_context => 'a custom context')
                end

                it "checks permission using the return value of the method" do
                  manager.should_receive(:can!).
                    with(permission, 'a custom context')
                  records_controller.process
                end

                it "raises error when there's no context" do
                  records_controller.stub(:custom_context => nil)
                  lambda {
                    records_controller.process
                  }.should raise_exception(AccessControl::NoContextError)
                end

              end

              context "is a symbol stating with @" do

                let(:test_context) { :@var_name }

                before do
                  records_controller.instance_variable_set('@var_name',
                                                           'a custom context')
                end

                it "checks permission using the variable value as context" do
                  manager.should_receive(:can!).
                    with(permission, 'a custom context')
                  records_controller.process
                end

                it "raises error when there's no context" do
                  records_controller.instance_variable_set('@var_name', nil)
                  lambda {
                    records_controller.process
                  }.should raise_exception(AccessControl::NoContextError)
                end

              end

              context "is a Proc" do

                let(:test_context) do
                  Proc.new { |controller| controller.custom_context }
                end

                before do
                  records_controller.stub(:custom_context).
                    and_return('a custom context')
                end

                it "checks permission using the return value of the proc" do
                  manager.should_receive(:can!).
                    with(permission, 'a custom context')
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

            context "when more than one permission is returned with the "\
                    "same context" do

              let(:test_context) { :current_context }

              it "caches the context" do
                another_permission =
                  RegistryFactory::Permission.new('another_permission')
                another_permission.context_designator[query_key] = test_context

                registry.stub(:query).
                  and_return(Set[permission, another_permission])

                records_controller.stub(:current_context) do
                  records_controller.fetched_context
                  node
                end
                records_controller.should_receive(:fetched_context).once

                records_controller.process
              end
            end

            it "doesn't check permission if security is disabled" do
              AccessControl.stub(:disabled?).and_return(true)
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
          AccessControl::Node.should_receive(:clear_global_cache).ordered
          records_controller.process do
            AccessControl::Node.block_called
          end
        end

        it "clears the anonymous principal cache" do
          AccessControl::Principal.should_receive(:block_called).ordered
          AccessControl::Principal.
            should_receive(:clear_anonymous_cache).ordered
          records_controller.process do
            AccessControl::Principal.block_called
          end
        end

        it "tells PermissionInspector to clear its role cache" do
          PermissionInspector.should_receive(:block_called).ordered
          PermissionInspector.should_receive(:clear_role_cache).ordered

          records_controller.process do
            PermissionInspector.block_called
          end
        end
      end

    end

    describe "#current_context" do

      # This method should return one or mode nodes for permission checking,
      # and it is meant to be overridden by application code.  By default
      # return the global node.

      before do
        AccessControl.stub(:global_node).and_return('the global node')
      end

      it "returns the global node" do
        records_controller.send(:current_context).should == 'the global node'
      end

      it "is declared private" do
        # This should not be public since it is not an action.
        records_controller.private_methods.should(include(:current_context))
      end

    end

  end
end
