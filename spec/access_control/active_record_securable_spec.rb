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
        def self.primary_key
          'pk'
        end
        def pk
          123
        end
      end
    end

    let(:model) { Class.new(base) }

    it "includes just after callbacks" do
      model.send(:include, ActiveRecordSecurable)
      model.should include(ActiveRecordJustAfterCallback)
    end

    context "in a model with ActiveRecordSecurable" do
      let(:node)     { stub('node') }
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

      it "persists the node when the record is created" do
        node.should_receive(:securable_id=).with(instance.pk).ordered
        node.should_receive(:persist!).ordered
        instance.create
      end

      it "persists the node when the record is updated and a node wasn't "\
         "created yet" do
        instance.stub(:ac_node => node)
        node.stub(:persisted?).and_return(false)
        node.should_receive(:persist!)
        instance.update
      end

      it "does nothing when the record is updated and a node was already "\
         "created" do
        instance.stub(:ac_node => node)
        node.stub(:persisted?).and_return(true)
        node.should_not_receive(:persist!)
        instance.update
      end

      it "destroys the node when the record is destroyed" do
        node.should_receive(:destroy)
        instance.destroy
      end
    end
  end
end
