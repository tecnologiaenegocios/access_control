require 'spec_helper'
require 'access_control/active_record_securable'

module AccessControl
  describe ActiveRecordSecurable do
    # A Mix-in module for ActiveRecord models.

    let(:base) do
      Class.new do
        def create
          self.class.just_after_callback_chains.execute(self, :create)
        end
        def update
          self.class.just_after_callback_chains.execute(self, :update)
        end
        def destroy
          self.class.just_after_callback_chains.execute(self, :destroy)
        end
      end
    end

    let(:model) { Class.new(base) }

    let(:manager)       { stub('manager') }
    let(:principals)    { ['principal1', 'principal2'] }
    let(:default_roles) { stub('default roles subset') }

    before do
      AccessControl.stub(:manager).and_return(manager)
      manager.stub(:principals).and_return(principals)
      Role.stub(:default).and_return(default_roles)
      Role.stub(:assign_all)
    end

    it "includes just after callbacks" do
      model.send(:include, ActiveRecordSecurable)
      model.should include(ActiveRecordJustAfterCallback)
    end

    describe "associated node" do
      let(:node)     { stub('node', :persist! => nil) }
      let(:instance) { model.new }

      before do
        Node.stub(:for_securable).with(instance).and_return(node)
        model.send(:include, ActiveRecordSecurable)
      end

      it "returns a node for the instance" do
        instance.ac_node.should be node
      end

      specify "once the node is computed, the node is cached" do
        old_result = instance.ac_node # should cache
        Node.should_not_receive(:for_securable)
        instance.ac_node.should be old_result
      end

      describe "persistency and removal of the node" do
        it "persists the node when the record is saved" do
          PersistencyProtector.stub(:verify_attachment!)
          node.should_receive(:persist!)
          instance.create
        end

        it "destroys the node when the record is destroyed" do
          PersistencyProtector.stub(:verify_detachment!)
          node.should_receive(:destroy)
          instance.destroy
        end
      end

      describe "setting default roles on the node created" do
        before do
          PersistencyProtector.stub(:verify_attachment!)
          instance.stub(:ac_node).and_return(node)
        end

        it "sets default roles by assigning them to the node and principals" do
          Role.should_receive(:assign_all).with(default_roles, principals, node)
          instance.create
        end

        it "does that after persisting the node" do
          node.should_receive(:persist!).ordered
          node.should_receive(:called_on_assignment).ordered

          Role.define_singleton_method(:assign_all) do |r, p, n|
            n.called_on_assignment
          end

          instance.create
        end
      end
    end

    describe "tracking parents" do

      before do
        PersistencyProtector.stub(:track_parents)
        model.send(:include, ActiveRecordSecurable)
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
        PersistencyProtector.stub(:track_parents)
        ActiveRecordAssociator.stub(:setup_association)
        model.send(:include, ActiveRecordSecurable)
        instance.stub(:ac_node)
      end

      describe "on create" do
        it "verifies attachment just after create" do
          # This sounds strange, but without permissions the creation will be
          # rolled back, thus the user will not succeed in create the object.
          PersistencyProtector.should_receive(:verify_attachment!).
            with(instance)
          instance.create
        end
      end

      describe "on update" do
        it "verifies attachment just after update" do
          PersistencyProtector.should_receive(:verify_attachment!).
            with(instance)
          instance.update
        end

        it "verifies detachment just after update" do
          PersistencyProtector.should_receive(:verify_detachment!).
            with(instance)
          instance.update
        end

        it "verifies update permissions just after update" do
          # This sounds strange, but without permissions the update will be
          # rolled back, thus the user will not succeed in update the object.
          PersistencyProtector.should_receive(:verify_update!).with(instance)
          instance.update
        end
      end

      describe "on destroy" do
        it "verifies destroy permissions just after destruction" do
          # This sounds strange, but without permissions the destruction will
          # be rolled back, thus the user will not succeed in destroy the
          # object.
          PersistencyProtector.should_receive(:verify_detachment!).
            with(instance)
          instance.destroy
        end
      end

    end

  end
end
