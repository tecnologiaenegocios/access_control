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

    it "includes just after callbacks" do
      model.send(:include, ActiveRecordSecurable)
      model.should include(ActiveRecordJustAfterCallback)
    end

    context "in a model with ActiveRecordSecurable" do
      let(:node)     { stub('node', :persist! => nil) }
      let(:instance) { model.new }
      let(:node_manager) { mock('node manager') }

      before do
        model.send(:include, ActiveRecordSecurable)
        Node.stub(:for_securable).with(instance).and_return(node)
        NodeManager.stub(:new).and_return(node_manager)
      end

      it "returns a node for the instance" do
        instance.ac_node.should be node
      end

      specify "once the node is computed, the node is cached" do
        old_result = instance.ac_node # should cache
        Node.should_not_receive(:for_securable)
        instance.ac_node.should be old_result
      end

      describe "when securable instance is created" do
        let(:principals)    { ['principal1', 'principal2'] }
        let(:default_roles) { stub('default roles subset') }

        it "assigns default roles and refreshes parents of the node" do
          node_manager.should_receive(:assign_default_roles).ordered
          node_manager.should_receive(:refresh_parents).ordered
          instance.stub(:ac_node => node)

          instance.create
        end
      end

      describe "when securable instance is updated" do
        it "refreshes parents and then check for update rights" do
          node_manager.should_receive(:refresh_parents).ordered
          node_manager.should_receive(:can_update!).ordered
          instance.stub(:ac_node => node)

          instance.update
        end
      end
    end
  end
end
