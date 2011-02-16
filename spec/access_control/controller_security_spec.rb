require 'spec_helper'

module AccessControl
  describe ControllerSecurity do

    let(:test_controller) do
      TestController.new
    end

    before do
      class ::Object::TestController
        include ControllerSecurity::InstanceMethods
      end
    end

    after do
      Object.send(:remove_const, 'TestController')
    end

    describe "#current_groups" do

      # There is by default an implementation of `current_groups` thar is
      # private and returns an empty array.  This simplifies the common case
      # where there's no concept of user groups.

      it "returns an empty array" do
        test_controller.send(:current_groups).should == []
      end

      it "is declared private" do
        test_controller.private_methods.should(
          include('current_groups')
        )
      end
    end

    describe "around filter for setting security manager" do

      it "sets security manager before action, unsets after" do
        AccessControl.should_receive(:set_security_manager).with(
          test_controller
        ).ordered
        AccessControl.should_receive(:no_security_manager).ordered
        test_controller.send(:run_with_security_manager) {}
      end

      it "is declared private" do
        test_controller.private_methods.should(
          include('run_with_security_manager')
        )
      end

    end

    describe "#current_security_context" do

      it "returns nil by default (no context)" do
        test_controller.send(:current_security_context).should be_nil
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
        Object.const_set(:CONTROLLER, test_controller)
        test_controller.class.instance_eval do
          # Make the before filter call the block immediately.
          def before_filter action, &block
            block.call(CONTROLLER)
          end
        end
        test_controller.stub!(:current_security_context).and_return(node)
        AccessControl.stub!(:get_security_manager).and_return(manager)
        manager.stub!(:verify_access!)
      end

      it "raises an error when there's no security context" do
        test_controller.should_receive(:current_security_context).
          and_return(nil)
        lambda {
          test_controller.class.class_eval do
            protect :some_action, :with => 'some permission'
          end
        }.should raise_exception(::AccessControl::NoSecurityContextError)
      end

      it "works when `current_security_context` is protected" do
        test_controller.metaclass.class_eval do
          protected :current_security_context
          protect :some_action, :with => 'some permission'
        end
      end

      it "works when `current_security_context` is private" do
        test_controller.metaclass.class_eval do
          private :current_security_context
          protect :some_action, :with => 'some permission'
        end
      end

      describe "with string permission" do
        it "protects an action with permissions provided" do
          manager.should_receive(:verify_access!).
            with(node, Set.new(['some permission']))
          test_controller.class.class_eval do
            protect :some_action, :with => 'some permission'
          end
        end
      end

      describe "with array of permissions" do
        it "protects an action with permissions provided" do
          manager.should_receive(:verify_access!).
            with(node, Set.new(['some permission']))
          test_controller.class.class_eval do
            protect :some_action, :with => ['some permission']
          end
        end
      end

      describe "with set of permissions" do
        it "protects an action with permissions provided" do
          manager.should_receive(:verify_access!).
            with(node, Set.new(['some permission']))
          test_controller.class.class_eval do
            protect :some_action, :with => Set.new(['some permission'])
          end
        end
      end

      after do
        Object.send(:remove_const, :CONTROLLER)
      end

    end

  end
end
