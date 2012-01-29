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
      let(:node)     { stub('node', :securable_id= => nil) }
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

      describe "when securable instance is created" do
        let(:principals)    { ['principal1', 'principal2'] }
        let(:default_roles) { stub('default roles subset') }

        before do
          node.stub(:persist!)
          node.stub(:refresh_parents)
          Role.stub(:assign_default_at)
          AccessControl.stub(:Node).with(node).and_return(node)
        end

        it "persists the node when the record is saved" do
          node.should_receive(:securable_id=).with(instance.pk).ordered
          node.should_receive(:persist!).ordered
          instance.create
        end

        it "assigns default roles and refreshes parents of the node" do
          Role.should_receive(:assign_default_at).with(node)
          node.should_receive(:refresh_parents)
          instance.stub(:ac_node => node)

          instance.create
        end

        it "makes the assignment after the node is saved" do
          Role.stub(:assign_default_at) do |*args|
            node.do_assignment
          end
          node.should_receive(:persist!).ordered
          node.should_receive(:do_assignment).ordered

          instance.create
        end
      end

      describe "when securable instance is updated" do
        it "refreshes parents and then check for update rights" do
          node.should_receive(:refresh_parents).ordered
          node.should_receive(:can_update!).ordered
          instance.stub(:ac_node => node)

          instance.update
        end
      end

      it "destroys the node when the record is destroyed" do
        node.should_receive(:destroy)
        instance.destroy
      end
    end
  end
end
