require 'spec_helper'
require 'access_control/node'

module AccessControl
  class Node
    describe Persistent do
      it "is extended with AccessControl::Ids" do
        Persistent.singleton_class.should include(AccessControl::Ids)
      end

      let(:manager)         { Manager.new }
      let(:securable_class) { FakeSecurableClass.new }
      let(:securable)       { securable_class.new }

      before do
        AccessControl.stub(:manager).and_return(manager)
      end

      describe ".with_type" do
        let(:node1) do
          Persistent.create!(:securable_type => 'SomeType', :securable_id => '2341')
        end
        let(:node2) do
          Persistent.create!(:securable_type => 'AnotherType', :securable_id => '2341')
        end

        subject { Persistent.with_type('SomeType') }

        it { should discover(node1) }
        it { should_not discover(node2) }

        context "using an array" do
          subject { Persistent.with_type(['SomeType', 'AnotherType']) }
          it { should discover(node1, node2) }
        end
      end

      describe ".blocked and .unblocked" do
        let(:blocked_node) do
          Persistent.create!(:securable_type => 'Foo', :securable_id => 0,
                       :block => true)
        end
        let(:unblocked_node) do
          Persistent.create!(:securable_type => 'Foo', :securable_id => 0,
                       :block => false)
        end

        describe ".blocked" do
          subject { Persistent.blocked }
          it { should discover(blocked_node) }
          it { should_not discover(unblocked_node) }
        end

        describe ".unblocked" do
          subject { Persistent.unblocked }
          it { should discover(unblocked_node) }
          it { should_not discover(blocked_node) }
        end
      end

      describe ".granted_for" do
        let(:nodes) do
          securable_types = %w[RightType WrongType].cycle
          securable_ids   = [0, 1, 2, 3]

          securable_ids.map do |securable_id|
            securable_type = securable_types.next
            Persistent.create!(:securable_type => securable_type,
                               :securable_id   => securable_id)
          end
        end

        let(:node_ids)    { nodes.map(&:id) }
        let(:assignments) { stub('assignments', :node_ids => node_ids) }

        let(:nodes_with_the_right_attributes) do
          items_from(nodes).with(:securable_type => 'RightType',
                                 :id => node_ids.first)
        end

        before do
          Assignment.stub(:granting_for_principal).and_return(assignments)
        end

        def get_granted_nodes
          Persistent.granted_for('RightType', 'principal ids', 'permissions')
        end

        it "gets relevant assignments for permission and principal" do
          Assignment.should_receive(:granting_for_principal).
            with('permissions', 'principal ids').and_return(assignments)
          get_granted_nodes
        end

        it "gets only the ids" do
          assignments.should_receive(:node_ids).and_return('node ids')
          get_granted_nodes
        end

        subject { get_granted_nodes }

        it { should discover(*nodes_with_the_right_attributes) }
        it { should respond_to(:sql) }
      end

      describe ".blocked_for" do

        let(:nodes) do
          count = 0
          combine_values(:securable_type => ['RightType', 'WrongType'],
                         :block => [true, false]) do |attrs|
            count += 1
            Persistent.create!(attrs.merge(:securable_id => count))
          end
        end

        subject { Persistent.blocked_for('RightType') }

        it { should discover(*items_from(nodes).
                             with(:securable_type => 'RightType',
                                  :block => true)) }

        it { subject.respond_to?(:sql).should be_true }
      end
    end
  end
end
