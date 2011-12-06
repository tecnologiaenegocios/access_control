require 'spec_helper'
require 'access_control/active_record_securable'

module AccessControl
  describe ActiveRecordSecurable do
    # A Mix-in module for ActiveRecord models.

    let(:base) do
      Class.new do
        def self.primary_key
          'id'
        end
        def id
          1000
        end
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

      let(:protector) { stub('protector', :verify! => nil) }
      let(:instance) { model.new }

      before do
        Node.stub(:create!)
        PersistencyProtector.stub(:new).with(instance).and_return(protector)
        instance.extend(ActiveRecordSecurable)
      end

      describe "on create" do
        before { instance.stub(:ac_node) }
        it "verifies the create permission" do
          protector.should_receive(:verify!).with('create')
          instance.send(:create)
        end
        it "does it right after the record is created" do
          protector.stub(:verify!) do |action|
            instance.verified
          end
          instance.should_receive(:do_action).ordered
          instance.should_receive(:verified).ordered
          instance.send(:create)
        end
        it "does it right before any after callback is called" do
          protector.stub(:verify!) do |action|
            instance.verified
          end
          instance.should_receive(:verified).ordered
          instance.should_receive(:run_after_create_callbacks).ordered
          instance.send(:create)
        end
      end

      describe "on update" do
        it "verifies the update permission" do
          protector.should_receive(:verify!).with('update')
          instance.send(:update, 'some', 'arguments')
        end
        it "does it before doing the real update" do
          exception = Class.new(StandardError)
          protector.stub(:verify!).and_raise(exception)
          instance.should_not_receive(:do_action)
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
          protector.should_receive(:verify!).with('destroy')
          instance.send(:destroy)
        end
        it "does it before doing the real update" do
          exception = Class.new(StandardError)
          protector.stub(:verify!).and_raise(exception)
          instance.should_not_receive(:do_action)
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
