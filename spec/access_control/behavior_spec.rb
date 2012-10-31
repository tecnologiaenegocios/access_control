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

    context "when the access control is disabled" do
      before do
        AccessControl.disable!
      end

      after do
        AccessControl.enable!
      end

      it "returns a NullManager" do
        AccessControl.manager.should be_a(AccessControl::NullManager)
      end

      it "returns always the same null manager" do
        previous_manager = AccessControl.manager
        current_manager = AccessControl.manager

        previous_manager.should equal(current_manager)
      end
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

  describe ".unrestrict_method" do
    let(:klass)        { Class.new }
    let(:instance)     { klass.new }
    let(:manager)      { stub('Manager') }
    let(:return_value) { stub("Return value") }

    before do
      AccessControl.stub(:manager).and_return(manager)

      manager.define_singleton_method(:trust) do |&block|
        block.call
      end
    end

    it "removes restrictions from an already defined instance method" do
      callstack = []

      klass.class_eval do
        define_method(:my_method) do
          callstack << :method_body
        end
      end

      AccessControl.unrestrict_method(klass, :my_method)

      manager.define_singleton_method(:trust) do |&block|
        callstack << :trust_start
        block.call
        callstack << :trust_end
      end

      instance.my_method
      callstack.should == [:trust_start, :method_body, :trust_end]
    end

    it "maintains the reception of arguments" do
      klass.class_eval do
        define_method(:sum) do |value1, value2|
          value1 + value2
        end
      end

      AccessControl.unrestrict_method(klass, :sum)

      instance.sum(1,2).should == 3
    end

    it "maintains the reception of blocks" do
      klass.class_eval do
        define_method(:block_based_method) do |&block|
          block.call
        end
      end

      AccessControl.unrestrict_method(klass, :block_based_method)

      block_called = false
      instance.block_based_method do
        block_called = true
      end

      block_called.should be_true
    end

    specify "before any unrestriction, .unrestrict_method? returns false" do
      AccessControl.should_not be_unrestricted_method(klass, :object_id)
    end

    specify "once an unrestriction is applied, .unrestrict_method? returns true" do
      AccessControl.unrestrict_method(klass, :object_id)

      AccessControl.should be_unrestricted_method(klass, :object_id)
    end

    it "doesn't mix unrestrictions from different classes" do
      AccessControl.unrestrict_method(Class.new, :object_id)

      AccessControl.should_not be_unrestricted_method(klass, :object_id)
    end
  end

  describe ".disable! and enable!" do
    after do
      AccessControl.enable!
    end

    specify "AccessControl is enabled by default" do
      AccessControl.should_not be_disabled
    end

    context "when AccessControl is enabled" do
      context "and .disable! is called" do
        it "causes the AccessControl to be disabled" do
          AccessControl.disable!
          AccessControl.should be_disabled
        end
      end
    end

    context "when AccessControl is disabled" do
      before do
        AccessControl.disable!
      end

      context "and .enable! is called" do
        it "causes the AccessControl to be enabled" do
          AccessControl.enable!
          AccessControl.should_not be_disabled
        end
      end
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

  describe ".refresh_parents_of" do
    context "when access control is enabled" do
      it "delegatest to NodeManager" do
        securable = stub
        AccessControl::NodeManager.
          should_receive(:refresh_parents_of).with(securable)
        AccessControl.refresh_parents_of(securable)
      end
    end

    context "when access control is disabled" do
      before do
        AccessControl.disable!
      end

      after do
        AccessControl.enable!
      end

      it "does nothing" do
        AccessControl::NodeManager.should_not_receive(:refresh_parents_of)
        AccessControl.refresh_parents_of('ignored')
      end
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

      stub("Inheritance", :relationships => hashes)
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

  describe ".registry" do
    it "just returns the AccessControl::Registry constant" do
      AccessControl.registry.should == AccessControl::Registry
    end
  end

  describe ".permissions_for_method" do
    include WithConstants

    let_constant(:model) do
      new_class(:Securable, Class.new) do
        def foo; end
      end
    end

    context "in models with an unprotected method" do
      it "returns an empty collection" do
        AccessControl.permissions_for_method(model, :foo).should be_empty
      end
    end

    context "in models with a protected method" do
      before do
        model.class_eval do
          include AccessControl::MethodProtection
          protect :foo, :with => 'permission'
        end
      end

      it "returns the permissions" do
        AccessControl.
          permissions_for_method(model, :foo).
          map(&:name).should include_only('permission')
      end

      context "in subclasses of the model" do
        let_constant(:submodel) { new_class(:SubSecurable, model) }

        it "returns the permissions" do
          AccessControl.
            permissions_for_method(submodel, :foo).
            map(&:name).should include_only('permission')
        end
      end

      context "in subclasses which set new permissions" do
        let_constant(:submodel) { new_class(:SubSecurable, model) }

        before do
          submodel.class_eval do
            include AccessControl::MethodProtection
            protect :foo, :with => 'new permission'
          end
        end

        it "returns the permissions plus the additional ones" do
          AccessControl.
            permissions_for_method(submodel, :foo).
            map(&:name).should include_only('new permission')
        end
      end
    end

    context "in models with a protected method which are subclasses" do
      let_constant(:submodel) { new_class(:SubSecurable, model) }

      before do
        submodel.class_eval do
          include AccessControl::MethodProtection
          protect :foo, :with => 'permission'
        end
      end

      it "returns the permissions" do
        AccessControl.
          permissions_for_method(submodel, :foo).
          map(&:name).should include('permission')
      end
    end
  end

  describe ".clear" do
    # In the future the declarations in Macros and in ControllerSecurity will
    # not keep data outside the registry, and this method will be removed.
    # Only a call to clear the registry (which is exposed as part of our public
    # API) will be needed.
    it "clears macro declarations, controller security and registry" do
      AccessControl::ControllerSecurity.should_receive(:clear)
      AccessControl::Macros.should_receive(:clear)

      AccessControl::Registry.should_receive(:clear)

      AccessControl.clear
    end
  end

  describe ".reset" do
    it "clears macro declarations, controller security, registry and inheritance" do
      # In the future the declarations in Macros and in ControllerSecurity
      # will not keep data outside the registry, so the following calls will
      # not be necessary anymore.
      AccessControl::ControllerSecurity.should_receive(:clear)
      AccessControl::Macros.should_receive(:clear)

      AccessControl::Registry.should_receive(:clear)
      AccessControl::Inheritance.should_receive(:clear)
      AccessControl::ActiveRecordAssociation.should_receive(:clear)

      AccessControl.reset
    end
  end

  describe AccessControl::GlobalRecord do
    subject { AccessControl::GlobalRecord.instance }

    it "cannot be instantiated" do
      lambda { AccessControl::GlobalRecord.new }.should raise_exception
    end

    it "has id == 1" do
      # The id is 1 and not 0 because we're using 0 for class nodes.
      subject.id.should == 1
    end

    # Why?
    # it { should be_a AccessControl::Securable }
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
