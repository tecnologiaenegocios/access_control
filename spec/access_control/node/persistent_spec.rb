require 'spec_helper'

module AccessControl
  class Node
    describe Persistent do
      let(:manager)         { Manager.new }
      let(:securable_class) { FakeSecurableClass.new }
      let(:securable)       { securable_class.new }

      before do
        AccessControl.stub(:manager).and_return(manager)
      end

      describe ".blocked" do
        let(:node1) do
          Persistent.create(:securable_type => 'SomeType',
                            :securable_id => '1', :block => true)
        end
        let(:node2) do
          Persistent.create(:securable_type => 'SomeType',
                            :securable_id => '2', :block => false)
        end

        subject { Persistent.blocked }

        it { should discover(node1) }
        it { should_not discover(node2) }
      end

      describe ".with_type" do
        let(:node1) do
          Persistent.create(:securable_type => 'SomeType', :securable_id => '2341')
        end
        let(:node2) do
          Persistent.create(:securable_type => 'AnotherType', :securable_id => '2341')
        end

        subject { Persistent.with_type('SomeType') }

        it { should discover(node1) }
        it { should_not discover(node2) }

        context "using an array" do
          subject { Persistent.with_type(['SomeType', 'AnotherType']) }
          it { should discover(node1, node2) }
        end
      end

      describe ".with_ids" do
        def build_node(securable_id)
          Persistent.create(:securable_type => 'irrelevant',
                            :securable_id   => securable_id)
        end

        let!(:node1) { build_node(1234) }
        let!(:node2) { build_node(4321) }

        it "includes nodes whose securable id is in the parameter" do
          Persistent.with_securable_id(1234).should include(node1)
        end

        it "doesn't include nodes whose securable id is not in the parameter" do
          Persistent.with_securable_id(1234).should_not include(node2)
        end
      end

      describe ".for_securables" do
        def build_node(securable_type, securable_id)
          Persistent.create(:securable_type => securable_type,
                            :securable_id   => securable_id)
        end
        let(:foo_class) { stub(:name => "Foo") }
        let(:bar_class) { stub(:name => "Bar") }

        let(:foo)    { stub(:class => foo_class, :id => 1234) }
        let(:bar)    { stub(:class => bar_class, :id => 1234) }

        let!(:node1) { build_node("Foo", 1234) }
        let!(:node2) { build_node("Foo", 4321) }
        let!(:node3) { build_node("Bar", 1234) }
        let!(:node4) { build_node("Bar", 4321) }

        it "returns nodes that the securable's type and id" do
          dataset = Persistent.for_securables(foo)
          dataset.should include(node1)
        end

        it "doesn't return nodes that match securable_type but not securable_id" do
          dataset = Persistent.for_securables(foo)
          dataset.should_not include(node2)
        end

        it "doesn't return nodes that match securable_id but not securable_type" do
          dataset = Persistent.for_securables(foo)
          dataset.should_not include(node3)
        end

        it "doesn't return nodes that match none" do
          dataset = Persistent.for_securables(foo)
          dataset.should_not include(node4)
        end

        context "when a collection of securables is given" do
          it "returns nodes that match one securable exactly" do
            dataset = Persistent.for_securables([foo, bar])
            dataset.should include(node1, node3)
          end

          it "doesn't return nodes that match none of the securables" do
            dataset = Persistent.for_securables([foo, bar])
            dataset.should_not include(node2, node4)
          end
        end
      end
    end
  end
end
