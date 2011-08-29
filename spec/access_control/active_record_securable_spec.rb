require 'spec_helper'
require 'access_control/active_record_securable'

module AccessControl
  describe ActiveRecordSecurable do
    # A Mix-in module for ActiveRecord models.

    let(:base) do
      Class.new do
      private
        def create
          create_without_callbacks
          run_after_create_callbacks
        end
        def update(*args)
          do_action
        end
        def destroy
          do_action
        end
        def create_without_callbacks; do_action; end
        def run_after_create_callbacks; end
        def do_action; end
      end
    end

    let(:model) { Class.new(base) }

    before do
      base.stub(:after_create)
      base.stub(:has_one)
    end

    it "includes associator" do
      model.send(:include, ActiveRecordSecurable)
      model.should include(ActiveRecordAssociator)
    end

    it "includes declarations" do
      model.send(:include, ActiveRecordSecurable)
      model.should include(Declarations)
    end

    it "configures an association for Node" do
      Node.should_receive(:name).and_return("Node's class name")
      model.should_receive(:associate_with_access_control).
        with(:ac_node, "Node's class name", :securable)
      model.send(:include, ActiveRecordSecurable)
    end

    describe "persistency protection" do

      let(:manager) { mock('manager', :verify_access! => nil) }
      let(:instance) { model.new }

      before do
        AccessControl.stub(:security_manager).and_return(manager)
        model.send(:include, ActiveRecordSecurable)
        model.stub(:permissions_required_to_create).
          and_return(Set.new(['some permissions']))
        model.stub(:permissions_required_to_update).
          and_return(Set.new(['some permissions']))
        model.stub(:permissions_required_to_destroy).
          and_return(Set.new(['some permissions']))
      end

      describe "on create" do
        it "verifies the create permission" do
          model.stub(:permissions_required_to_create).
            and_return(Set.new(['some permissions']))
          manager.should_receive(:verify_access!).
            with(instance, Set.new(['some permissions']))
          instance.send(:create)
        end
        it "does it right after the record is created" do
          manager.stub(:verify_access!) do |instance, permissions|
            instance.verified
          end
          instance.should_receive(:do_action).ordered
          instance.should_receive(:verified).ordered
          instance.send(:create)
        end
        it "does it right before any after callback is called" do
          manager.stub(:verify_access!) do |instance, permissions|
            instance.verified
          end
          instance.should_receive(:verified).ordered
          instance.should_receive(:run_after_create_callbacks).ordered
          instance.send(:create)
        end
      end

      describe "on update" do
        it "verifies the update permission" do
          model.stub(:permissions_required_to_update).
            and_return(Set.new(['some permissions']))
          manager.should_receive(:verify_access!).
            with(instance, Set.new(['some permissions']))
          instance.send(:update, 'some', 'arguments')
        end
        it "does it before doing the real update" do
          exception = Class.new(StandardError)
          manager.stub(:verify_access!).and_raise(exception)
          model.should_not_receive(:do_action)
          begin
            instance.send(:update, 'some', 'arguments')
          rescue exception
            # pass
          end
        end
        it "forwards to the super class method" do
          instance.should_receive(:do_action)
          instance.send(:update, 'some', 'arguments')
        end
      end

      describe "on destroy" do
        it "verifies the destroy permission" do
          model.stub(:permissions_required_to_destroy).
            and_return(Set.new(['some permissions']))
          manager.should_receive(:verify_access!).
            with(instance, Set.new(['some permissions']))
          instance.send(:destroy)
        end
        it "does it before doing the real update" do
          exception = Class.new(StandardError)
          manager.stub(:verify_access!).and_raise(exception)
          model.should_not_receive(:do_action)
          begin
            instance.send(:destroy)
          rescue exception
            # pass
          end
        end
        it "forwards to the super class method" do
          instance.should_receive(:do_action)
          instance.send(:destroy)
        end
      end

    end

  end
end
