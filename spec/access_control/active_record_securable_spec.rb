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
          run_before_create_callbacks
          create_without_callbacks
          run_after_create_callbacks
        end
        def update(*args)
          run_before_update_callbacks
          update_without_callbacks
          run_after_update_callbacks
        end
        def destroy
          do_action
        end
        def create_without_callbacks; do_action; end
        def update_without_callbacks; do_action; end
        def run_before_create_callbacks; end
        def run_after_create_callbacks; end
        def run_before_update_callbacks; end
        def run_after_update_callbacks; end
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

    describe "tracking parents" do

      before do
        PersistencyProtector.stub(:track_parents)
        model.extend(ActiveRecordSecurable::ClassMethods)
      end

      # Tracking parents is needed for further calling the persistency
      # protector and have it check the instance for added/removed parents.

      # This is done either for .instantiate and for .new.  The reason for
      # doing so is that .find will call .allocate, which in turn will call
      # .instantiate, which returns a ready instance, whereas .new calls
      # #initialize which also returns a ready instance.  Instead of patching
      # #initialize and #find, it is easier to patch .instantiate and .new,
      # because the patch will be the same for both.

      [:instantiate, :new].each do |meth|
        context "when calling .#{meth}" do
          let(:instance) { stub('instance') }

          before do
            base.stub(meth).and_return(instance)
          end

          it "tell the protector to track the parents of the instance" do
            PersistencyProtector.should_receive(:track_parents).with(instance)
            model.send(meth)
          end

          it "return the instance created from superclass" do
            the_arguments = stub('arguments')
            correct_instance = stub
            base.stub(meth).with(the_arguments).and_return(correct_instance)
            model.send(meth, the_arguments).should == correct_instance
          end
        end
      end
    end

    describe "persistency protection" do

      let(:instance) { model.new }

      before do
        PersistencyProtector.stub(:verify_attachment!)
        PersistencyProtector.stub(:verify_detachment!)
        PersistencyProtector.stub(:verify_update!)
        instance.extend(ActiveRecordSecurable)
      end

      describe "on create" do
        it "verify attachment right after all before callbacks have run" do
          PersistencyProtector.stub(:verify_attachment!) do |instance|
            instance.verified
          end
          instance.should_receive(:run_before_create_callbacks).ordered
          instance.should_receive(:verified).ordered
          instance.send(:create)
        end
        it "forwards to the super class method" do
          instance.should_receive(:do_action)
          instance.send(:create)
        end
      end

      describe "on update" do
        it "verify detachment right after all before callbacks have run" do
          PersistencyProtector.stub(:verify_detachment!) do |instance|
            instance.verified
          end
          instance.should_receive(:run_before_update_callbacks).ordered
          instance.should_receive(:verified).ordered
          instance.send(:update, 'some', 'arguments')
        end
        it "verify attachment right after all before callbacks have run" do
          PersistencyProtector.stub(:verify_attachment!) do |instance|
            instance.verified
          end
          instance.should_receive(:run_before_update_callbacks).ordered
          instance.should_receive(:verified).ordered
          instance.send(:update, 'some', 'arguments')
        end
        it "verify update right after all before callbacks have run" do
          PersistencyProtector.stub(:verify_update!) do |instance|
            instance.verified
          end
          instance.should_receive(:run_before_update_callbacks).ordered
          instance.should_receive(:verified).ordered
          instance.send(:update, 'some', 'arguments')
        end
        it "forwards to the super class method" do
          instance.should_receive(:do_action)
          instance.send(:update, 'some', 'arguments')
        end
      end

      describe "on destroy" do
        it "verify detachment right before doing the destruction" do
          PersistencyProtector.stub(:verify_detachment!) do |instance|
            instance.verified
          end
          instance.should_receive(:verified).ordered
          instance.should_receive(:do_action).ordered
          instance.send(:destroy)
        end
        it "forwards to the super class method" do
          instance.should_receive(:do_action)
          instance.send(:destroy)
        end
      end

    end

  end
end
