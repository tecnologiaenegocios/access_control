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

    before do
      ActiveRecordSecurable.propagate_roles      = false
      ActiveRecordSecurable.assign_default_roles = false
    end

    after do
      ActiveRecordSecurable.propagate_roles      = true
      ActiveRecordSecurable.assign_default_roles = true
    end

    let(:model) { Class.new(base) }

    it "includes just after callbacks" do
      model.send(:include, ActiveRecordSecurable)
      model.should include(ActiveRecordJustAfterCallback)
    end

    describe "associated node" do
      let(:node)     { stub('node', :persist! => nil) }
      let(:instance) { model.new }

      before do
        Node.stub(:for_securable).with(instance).and_return(node)
      end

      describe "association" do
        before do
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
      end

      describe "setting default roles on the node created" do
        let(:principals)    { ['principal1', 'principal2'] }
        let(:default_roles) { stub('default roles subset') }

        before do
          ActiveRecordSecurable.assign_default_roles = true
          model.send(:include, ActiveRecordSecurable)

          Role.stub(:default => default_roles)
          AccessControl.stub_chain(:manager, :principals).and_return(principals)

          instance.stub(:ac_node => node)
        end

        it "sets default roles by assigning them to the node and principals" do
          Role.should_receive(:assign_all).with(default_roles, principals, node)
          instance.create
        end

        it "does that after persisting the node" do
          node.should_receive(:persist!).ordered
          node.should_receive(:called_on_assignment).ordered

          Role.stub(:assign_all) do |_, _, node|
            node.called_on_assignment
          end

          instance.create
        end
      end

      describe "propagating the roles from the parent nodes" do
        let(:propagation) { stub("Role propagation") }

        before do
          ActiveRecordSecurable.propagate_roles = true
          model.send(:include, ActiveRecordSecurable)

          instance.stub(:ac_node => node)
        end

        it "uses a 'RolePropagation' to do the job" do
          RolePropagation.stub(:new).with(node).and_return(propagation)
          propagation.should_receive(:propagate!)

          instance.create
        end
      end

    end
  end
end
