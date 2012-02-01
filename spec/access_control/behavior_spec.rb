require 'spec_helper'
require 'access_control/db'
require 'access_control/behavior'
require 'access_control/node'
require 'access_control/securable'

describe AccessControl do

  after do
    # Clear the instantiated manager.
    AccessControl.no_manager
  end

  describe ".manager" do

    it "returns a Manager" do
      AccessControl.manager.should be_a(AccessControl::Manager)
    end

    it "instantiates the manager only once" do
      first = AccessControl.manager
      second = AccessControl.manager
      first.should equal(second)
    end

    it "stores the manager in the current thread" do
      current_manager = AccessControl.manager
      thr_manager = nil
      Thread.new { thr_manager = AccessControl.manager }
      current_manager.should_not equal(thr_manager)
    end

  end

  describe ".global_node_id" do
    it "returns the global node's id" do
      global = stub(:id => "The global node ID")
      AccessControl::Node.stub(:global => global)

      AccessControl.global_node_id.should == "The global node ID"
    end
  end

  describe ".global_securable_type" do
    subject { AccessControl.global_securable_type }
    it { should == AccessControl::GlobalRecord.name }
  end

  describe ".global_securable_id" do
    subject { AccessControl.global_securable_id }
    it { should == AccessControl::GlobalRecord.instance.id }
  end

  describe ".global_node" do
    it "returns the global node" do
      global = stub
      AccessControl::Node.stub(:global => global)

      AccessControl.global_node.should == global
    end
  end

  describe ".anonymous_id" do
    it "returns the anonymous's id" do
      anonymous = stub(:id => "The anonymous ID")
      AccessControl::Principal.stub(:anonymous => anonymous)

      AccessControl.anonymous_id.should == "The anonymous ID"
    end
  end

  describe ".anonymous_subject_type" do
    subject { AccessControl.anonymous_subject_type }
    it { should == AccessControl::AnonymousUser.name }
  end

  describe ".anonymous_subject_id" do
    subject { AccessControl.anonymous_subject_id }
    it { should == AccessControl::AnonymousUser.instance.id }
  end

  describe ".anonymous" do
    it "returns the anonymous user" do
      anonymous = stub
      AccessControl::Principal.stub(:anonymous => anonymous)

      AccessControl.anonymous.should == anonymous
    end
  end

  describe ".clear_parent_relationships!" do
    it "erases all previous relationships" do
      AccessControl.ac_parents.insert(:parent_id => 666, :child_id => 666)
      AccessControl.clear_parent_relationships!

      AccessControl.ac_parents.all.should be_empty
    end
  end

  describe ".clear_blocked_parent_relationships!" do
    let(:parent1) { 1 }
    let(:parent2) { 2 }
    let(:child1)  { 3 }
    let(:child2)  { 4 }

    let(:inheritance1) { [parent1, child1] }
    let(:inheritance2) { [parent2, child2] }

    let(:inheritances) { [inheritance1, inheritance2] }

    before do
      blocked = stub
      blocked.stub(:select).with(:id).and_return([4]) # this child is blocked.
      AccessControl::Node::Persistent.stub(:blocked => blocked)

      inheritances.each do |parent, child|
        AccessControl.ac_parents.insert(:parent_id => parent,
                                        :child_id  => child)
      end
    end

    it "erases blocked node's parent relationships" do
      AccessControl.clear_blocked_parent_relationships!

      AccessControl.ac_parents.select_map([:parent_id, :child_id]).should ==
        [inheritance1]
    end
  end

  describe ".rebuild_parent_relationships" do
    let(:parent1) { 1 }
    let(:parent2) { 2 }
    let(:child1)  { 3 }
    let(:child2)  { 4 }

    let(:securable_class) { stub }

    before do
      AccessControl::Inheritance.stub(:inheritances_of).with(securable_class).
        and_return(inheritances)
      blocked = stub
      blocked.stub(:select).with(:id).and_return([5]) # this child is blocked.
      AccessControl::Node::Persistent.stub(:blocked => blocked)
    end

    let(:inheritance1) { stub_inheritance([parent1, child1]) }
    let(:inheritance2) { stub_inheritance([parent2, child2]) }

    let(:inheritances) { [inheritance1, inheritance2] }

    def stub_inheritance(*relationships)
      hashes = relationships.map do |parent, child|
        {:parent_id => parent, :child_id => child}
      end

      inheritance = stub("Inheritance", :relationships => hashes)
    end

    it "imports every parent-child tuple for each inheritance" do
      AccessControl.rebuild_parent_relationships(securable_class)
      tuples = AccessControl.ac_parents.select_map([:parent_id, :child_id])
      tuples.should include_only([parent1, child1], [parent2, child2])
    end

    context "with equivalent inheritances" do
      let(:inheritance2) { stub_inheritance([parent2, child2],
                                            [parent1, child1]) }

      it "doesn't cause a duplication" do
        AccessControl.rebuild_parent_relationships(securable_class)

        tuples = AccessControl.ac_parents.select_map([:parent_id, :child_id])

        tuples.should include_only([parent1, child1], [parent2, child2])
      end
    end

    context "when a inheritance returns a dataset" do
      let(:dataset) do
        AccessControl.db.
          select(:parent_nodes__id, :child_nodes__id).
          from(AccessControl.db.select(123 => :id) => :parent_nodes,
               AccessControl.db.select(456 => :id) => :child_nodes)
      end

      before do
        inheritance = stub(:relationships => dataset)
        AccessControl::Inheritance.stub(:inheritances_of).with(securable_class).
          and_return([inheritance])
      end

      it "works as expected" do
        AccessControl.rebuild_parent_relationships(securable_class)
        tuples = AccessControl.ac_parents.select_map([:parent_id, :child_id])

        tuples.should include_only([123,456])
      end
    end
  end

  describe AccessControl::GlobalRecord do
    subject { AccessControl::GlobalRecord.instance }

    it "cannot be instantiated" do
      lambda { AccessControl::GlobalRecord.new }.should raise_exception
    end

    it "has id == 1" do
      # The is is 1 and not 0 because we're using 0 for class nodes.
      subject.id.should == 1
    end

    it { should be_a AccessControl::Securable }
  end

  describe AccessControl::AnonymousUser do
    subject { AccessControl::AnonymousUser.instance }

    it "cannot be instantiated" do
      lambda { AccessControl::AnonymousUser.new }.should raise_exception
    end

    it "has id == 1" do
      # The is is 1 and not 0 because we're using 0 for class nodes.
      subject.id.should == 1
    end
  end
end
