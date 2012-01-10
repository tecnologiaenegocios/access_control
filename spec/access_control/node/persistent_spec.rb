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
    end
  end
end
