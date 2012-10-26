require 'spec_helper'
require 'access_control/behavior'
require 'access_control/configuration'
require 'access_control/node'

module AccessControl
  describe ".Node" do
    specify "when the argument is a Node, returns it untouched" do
      node = Node.new
      return_value = AccessControl.Node(node)

      return_value.should be node
    end

    specify "when the argument responds to .ac_node, its return value "\
            "is returned" do
      node = Node.new
      securable = stub("Securable", :ac_node => node)

      return_value = AccessControl.Node(securable)
      return_value.should be node
    end

    specify "when the argument is a GlobalRecord, returns the global node" do
      global_node = stub
      AccessControl.stub(:global_node).and_return(global_node)

      return_value = AccessControl.Node(GlobalRecord.instance)
      return_value.should be global_node
    end

    specify "launches Exception for non-recognized argument types" do
      random_object = stub.as_null_object

      lambda {
        AccessControl::Node(random_object)
      }.should raise_error(AccessControl::UnrecognizedSecurable)
    end
  end

  describe Node do
    before do
      NodeManager.stub(:refresh_parents_of)
    end

    after { Node.clear_global_cache }

    describe "initialization" do
      it "accepts :securable_class" do
        node = Node.new(:securable_class => Hash)
        node.securable_class.should == Hash
        node.securable_type.should  == 'Hash'
      end

      describe ":securable_class over :securable_type" do
        let(:properties) do
          props = ActiveSupport::OrderedHash.new
          props[:securable_class] = Hash
          props[:securable_type]  = 'String'
          props
        end

        let(:reversed_properties) do
          props = ActiveSupport::OrderedHash.new
          props[:securable_type]  = 'String'
          props[:securable_class] = Hash
          props
        end

        describe "when :securable_class is set before :securable_type" do
          it "prefers :securable_class" do
            node = Node.new(properties)
            node.securable_class.should == Hash
            node.securable_type.should  == 'Hash'
          end
        end

        describe "when :securable_class is set after :securable_type" do
          it "prefers :securable_class" do
            node = Node.new(reversed_properties)
            node.securable_class.should == Hash
            node.securable_type.should  == 'Hash'
          end
        end
      end
    end

    describe ".for_securable" do
      let(:securable_class) { FakeSecurable }
      let(:securable)       { securable_class.new }
      let(:securable_id)    { securable.id }
      let(:orm)             { stub }

      before do
        ORM.stub(:adapt_class).with(securable_class).and_return(orm)
        orm.stub(:pk_of).with(securable).and_return(securable_id)
      end

      context "when the record is already saved" do
        before { orm.stub(:persisted?).with(securable).and_return(true) }

        context "when a corresponding node exists" do
          let!(:node) do
            Node.store(:securable_class => securable_class,
                       :securable_id    => securable_id)
          end

          it "returns the existing node" do
            returned_node = Node.for_securable(securable)
            returned_node.should == node
          end

          it "uses the id returned by the ORM adapter" do
            securable.stub(:id).and_return(securable_id + 1000)
            node = Node.for_securable(securable)
            node.securable_id.should == securable_id
          end

          it "sets the securable to avoid unnecessary trips to the DB" do
            node = Node.for_securable(securable)
            node.securable.should == securable
          end
        end

        context "when a corresponding node doesn't exist" do
          it "returns a new Node with the correct properties set" do
            node = Node.for_securable(securable)
            node.securable_id.should    == securable_id
            node.securable_class.should == securable_class
          end

          it "sets the securable to avoid unnecessary trips to the DB" do
            node = Node.for_securable(securable)
            node.securable.should == securable
          end

          it "uses the id returned by the ORM adapter" do
            securable.stub(:id).and_return(securable_id + 1000)
            node = Node.for_securable(securable)
            node.securable_id.should == securable_id
          end

          it "doesn't persist the node" do
            node = Node.for_securable(securable)
            node.should_not be_persisted
          end
        end
      end

      context "when the record is a new one" do
        before { orm.stub(:persisted?).with(securable).and_return(false) }

        it "returns a new Node" do
          node = Node.for_securable(securable)
          node.should_not be_persisted
        end

        it "doesn't set the securable id" do
          node = Node.for_securable(securable)
          node.securable_id.should be_nil
        end

        it "doesn't persist the node" do
          node = Node.for_securable(securable)
          node.should_not be_persisted
        end

        it "sets the securable class of the new Node" do
          node = Node.for_securable(securable)
          node.securable_class.should == securable_class
        end

        it "sets the securable to avoid unnecessary trips to the DB" do
          node = Node.for_securable(securable)
          node.securable.should == securable
        end
      end
    end

    describe ".generate_for" do
      include WithConstants

      let(:node_dataset) { AccessControl.db[:ac_nodes] }

      after do
        AccessControl.db.drop_table(:securables)
      end

      context "normal, without STI, models" do
        let_constant(:model) do
          AccessControl.db.create_table(:securables) { primary_key :id }
          new_class(:Securable, Sequel::Model(:securables))
        end

        before do
          3.times { model.create }
        end

        it "creates as many nodes as there are securables for the given class" do
          Node.generate_for(model)
          node_dataset.filter(:securable_type => model.name).count.should == 3
        end

        it "uses the ids of the securables as :securable_id" do
          Node.generate_for(model)

          existing_securable_ids = node_dataset.
            filter(:securable_type => model.name).select_map(:securable_id)
          expected_securable_ids = model.select_map(:id)
          expected_securable_ids.should include_only(*existing_securable_ids)
        end

        it "doesn't create duplicates" do
          2.times { Node.generate_for(model) }
          node_dataset.filter(:securable_type => model.name).count.should == 3
        end
      end

      context "models with STI" do
        let_constant(:model) do
          AccessControl.db.create_table(:securables) do
            primary_key :id
            varchar     :mytype
          end
          new_class(:Securable, Sequel::Model(:securables)) do
            plugin :single_table_inheritance, :mytype
          end
        end

        let_constant(:sub_model) { new_class(:SubSecurable, model) }

        before do
          model.create
          3.times { sub_model.create }
        end

        it "creates as many nodes as there are securables for the given class" do
          Node.generate_for(sub_model)
          node_dataset.filter(:securable_type => sub_model.name).count.should == 3

          Node.generate_for(model)
          node_dataset.filter(:securable_type => model.name).count.should == 1
        end

        it "uses the ids and correct types" do
          Node.generate_for(sub_model)
          Node.generate_for(model)

          existing_securable_ids = node_dataset.
            filter(:securable_type => sub_model.name).
            select_map(:securable_id)
          expected_securable_ids = sub_model.select_map(:id)
          existing_securable_ids.should include_only(*expected_securable_ids)

          existing_securable_ids = node_dataset.
            filter(:securable_type => model.name).
            select_map(:securable_id)
          expected_securable_ids = model.filter(model.sti_key => model.name).
            select_map(:id)
          existing_securable_ids.should include_only(*expected_securable_ids)
        end

        it "doesn't create duplicates" do
          2.times { Node.generate_for(sub_model) }
          node_dataset.filter(:securable_type => sub_model.name).count.should == 3

          2.times { Node.generate_for(model) }
          node_dataset.filter(:securable_type => model.name).count.should == 1
        end
      end
    end

    describe ".clear_global_cache" do
      it "clears the global node cache" do
        prev_node = Node.global
        Node.clear_global_cache
        next_node = Node.global

        next_node.should_not be prev_node
      end
    end

    describe ".global" do

      it "is a node" do
        Node.global.should be_a(AccessControl::Node)
      end

      describe "the node returned" do
        it "has securable_id == AccessControl::GlobalRecord.instance.id" do
          Node.global.securable_id.should ==
            AccessControl::GlobalRecord.instance.id
        end

        it "has securable_type == AccessControl::GlobalRecord" do
          Node.global.securable_type.should ==
            AccessControl::GlobalRecord.name
        end

        it "is cached" do
          prev_node = Node.global
          next_node = Node.global

          next_node.should be prev_node
        end
      end

      specify "its #securable is the GlobalRecord" do
        Node.global.securable.should be AccessControl::GlobalRecord.instance
      end
    end

    describe ".global!" do
      describe "the node returned" do
        before do
          Node.clear_global_cache
          Node.global
        end

        it "has securable_id == AccessControl::GlobalRecord.instance.id" do
          Node.global!.securable_id.should ==
            AccessControl::GlobalRecord.instance.id
        end

        it "has securable_type == AccessControl::GlobalRecord" do
          Node.global!.securable_type.should ==
            AccessControl::GlobalRecord.name
        end

        it "is not cached" do
          prev_node = Node.global!
          next_node = Node.global!

          next_node.should_not be prev_node
        end

        it "updates the cache" do
          prev_node = Node.global!
          next_node = Node.global

          next_node.should be prev_node
        end
      end

      it "raises an exception if the global node wasn't created yet" do
        Node::Persistent.delete

        lambda {
          Node.global!
        }.should raise_exception(AccessControl::NoGlobalNode)
      end
    end

    describe "#global?" do
      let(:node) { Node.new }
      let(:global_id) { 1 }
      before { AccessControl.stub(:global_node_id).and_return(global_id) }

      subject { node }

      context "the node has the same id of the global node" do
        before { node.stub(:id).and_return(global_id) }
        it { should be_global }
      end

      context "the node has any other id" do
        before { node.stub(:id).and_return('any other id') }
        it { should_not be_global }
      end
    end

    describe "subset delegation" do
      it "delegates subset .with_type to the persistent model" do
        Node.delegated_subsets.should include(:with_type)
      end
      it "delegates subset .blocked to the persistent model" do
        Node.delegated_subsets.should include(:blocked)
      end
    end

    describe "#securable" do

      let(:model) { Class.new }
      let(:node)  { Node.new(:securable_class => model,
                             :securable_id    => securable_id) }
      let(:adapted) { stub }
      let(:manager) { stub }
      let(:securable_id) { 1000 }

      def build_securable
        # Strings compare char by char, but each time object_id changes.
        'securable'
      end

      before do
        ORM.stub(:adapt_class).with(model).and_return(adapted)
        AccessControl.stub(:manager).and_return(manager)

        manager.define_singleton_method(:without_query_restriction) do |&b|
          b.call
        end

        adapted.stub(:[]) do |id|
          if id == securable_id
            build_securable()
          else
            nil
          end
        end
      end

      it "gets the record by calling .[] in the adapted model" do
        securable = build_securable
        node.securable.should == securable
      end

      it "raises error if record is not found" do
        node.stub(:securable_id).and_return('another id')
        lambda { node.securable }.should raise_exception(NotFoundError)
      end

      it "gets the record in an unrestricted way" do
        adapted.should_receive_without_query_restriction(:[]) do
          node.securable
        end
      end

      it "is cached" do
        prev_securable = node.securable
        next_securable = node.securable

        next_securable.should be prev_securable
      end

      it "can be changed by using the setter" do
        node.securable = 'some other securable'
        node.securable.should == 'some other securable'
      end

      specify "#securable= does NOT change securable_type" do
        model.stub(:name).and_return('Foo')
        node.securable = stub(:securable_type => 'Bar')
        node.securable_type.should == 'Foo'
      end

      specify "#securable= does NOT change securable_id" do
        node.securable = stub(:securable_id => securable_id * 2)
        node.securable_id.should == securable_id
      end
    end

    describe "the securable's class" do
      it "is, by default, deduced from the securable_type string" do
        node = Node.new(:securable_type => "Hash")
        node.securable_class.should == Hash
      end

      it "can be set using an accessor" do
        node = Node.new(:securable_type => "Hash")
        node.securable_class = String

        node.securable_class.should == String
      end

      it "sets the securable_type accordingly" do
        node = Node.new(:securable_type => "Hash")
        node.securable_class = String

        node.securable_type.should == "String"
      end
    end

    describe "blocking and unblocking" do
      let(:securable_class) do
        FakeSecurableClass.new(:parents) do
          include Inheritance
          inherits_permissions_from :parents
        end
      end

      let(:adapted) do
        adapted = stub
        adapted.stub(:[]) { |id| securable_class.find(id) }
        adapted
      end

      def build_securable(parents=[])
        securable_class.new(:parents => parents)
      end

      let(:parent) do
        securable = build_securable
        parent = Node.store(:securable_class => securable.class,
                            :securable_id    => securable.id)
        securable.ac_node = parent
        parent
      end

      subject do
        securable = build_securable([parent.securable])
        Node.store(:securable_class => securable.class,
                   :securable_id    => securable.id)
      end

      before do
        ORM.stub(:adapt_class).with(securable_class).and_return(adapted)
        NodeManager.stub(:block)
        NodeManager.stub(:unblock)
      end

      specify "a new node is always unblocked" do
        Node.new.should_not be_blocked
      end

      specify "the global node is unblocked" do
        AccessControl.global_node.should_not be_blocked
      end

      describe "blocking a node" do
        it { subject.block = true; should be_blocked }

        it "perform blocking using NodeManager" do
          NodeManager.should_receive(:block).with(subject)
          subject.block = true
        end

        it "doesn't block using NodeManager if the node is already blocked" do
          subject.block = true
          NodeManager.should_not_receive(:block)
          subject.block = true
        end
      end

      describe "unblocking a node" do
        before { subject.block = true }
        it { subject.block = false; should_not be_blocked }

        it "perform unblocking using NodeManager" do
          NodeManager.should_receive(:unblock).with(subject)
          subject.block = false
        end

        it "doesn't unblock using NodeManager if the node is already "\
           "unblocked" do
          subject.block = false
          NodeManager.should_not_receive(:block)
          subject.block = false
        end
      end
    end

    describe "creating and updating" do

      let(:securable_class) { FakeSecurableClass.new }
      let(:securable)       { securable_class.new }

      subject { Node.new(:securable_class => securable_class,
                         :securable_id    => securable.id) }
      let(:persistent) { subject.persistent }

      it "returns false if not saved persistent node successfully" do
        persistent = subject.persistent
        persistent.stub(:save).and_return(false)

        subject.persist.should be_false
      end

      it "returns true if saved persistent node successfully" do
        persistent = subject.persistent
        persistent.stub(:save).and_return(true)

        subject.persist.should be_true
      end

      describe "on create" do
        before do
          persistent.stub(:new?).and_return(true)
        end

        context "when created successfully" do
          before do
            persistent.stub(:save).and_return(true)
          end

          it "assigns default role after the node is persisted" do
            Role.stub(:assign_default_at) do |*args|
              persistent.already_saved
            end
            persistent.should_receive(:save).ordered
            persistent.should_receive(:already_saved).ordered

            subject.persist
          end

          it "refreshes parents through NodeManager after the node is persisted" do
            NodeManager.stub(:refresh_parents_of) do |node|
              node.persistent.already_saved
            end
            persistent.should_receive(:save).ordered
            persistent.should_receive(:already_saved).ordered

            subject.persist
          end

          it "doesn't try to check update" do
            NodeManager.should_not_receive(:can_update!)
            subject.persist
          end
        end

        context "when not created successfully" do
          let(:persistent) { subject.persistent }

          before do
            persistent.stub(:save).and_return(false)
          end

          it "doesn't try to assign default roles" do
            Role.should_not_receive(:assign_default_at)
            subject.persist
          end

          it "doesn't try to refresh parents" do
            NodeManager.should_not_receive(:refresh_parents_of)
            subject.persist
          end
        end
      end

      describe "on update" do
        before do
          persistent.stub(:new?).and_return(false)
          NodeManager.stub(:can_update!)
        end

        context "when updated successfully" do
          before do
            persistent.stub(:save).and_return(true)
          end

          it "doesn't try to assign default roles" do
            Role.should_not_receive(:assign_default_at)
            subject.persist
          end

          it "refreshes parents and checks update through NodeManager after "\
             "persisting" do
            persistent.stub(:save) do
              NodeManager.already_saved
              true
            end

            NodeManager.should_receive(:already_saved).ordered
            NodeManager.should_receive(:refresh_parents_of).with(subject).ordered
            NodeManager.should_receive(:can_update!).with(subject).ordered

            subject.persist
          end
        end

        context "when not created successfully" do
          before do
            persistent.stub(:save).and_return(false)
          end

          it "doesn't try to check update" do
            NodeManager.should_not_receive(:can_update!)
            subject.persist
          end

          it "doesn't try to refresh parents" do
            NodeManager.should_not_receive(:refresh_parents_of)
            subject.persist
          end
        end
      end
    end

    describe "on #destroy" do
      let(:persistent) { Node::Persistent.new }
      let(:node)       { Node.wrap(persistent) }

      before do
        Role.stub(:unassign_all_at).with(node)
        NodeManager.stub(:disconnect).with(node)
        persistent.stub(:destroy)
      end

      it "destroys all role assignments associated when it is destroyed" do
        Role.should_receive(:unassign_all_at).with(node)
        node.destroy
      end

      it "disconnects the node from the hierarchy" do
        NodeManager.should_receive(:disconnect).with(node)
        node.destroy
      end

      it "destroys persistent after unassigning roles" do
        Role.stub(:unassign_all_at) do
          persistent.already_unassigned_roles
        end
        persistent.should_receive(:already_unassigned_roles).ordered
        persistent.should_receive(:destroy).ordered

        node.destroy
      end

      it "destroys persistent after disconnecting the node" do
        NodeManager.stub(:disconnect) do |node|
          persistent.already_disconnected
        end
        persistent.should_receive(:already_disconnected).ordered
        persistent.should_receive(:destroy).ordered

        node.destroy
      end
    end

    describe ".normalize_collection" do
      let(:node) { Node.new }

      context "when given a single Node instance" do
        it "returns a singleton collection containing the node untoucheD" do
          return_value = Node.normalize_collection(node)
          return_value.should include_only(node)
        end
      end

      context "when given a single Securable instance" do
        it "returns a singleton collection with the securable's node" do
          securable = stub(:ac_node => node)
          return_value = Node.normalize_collection(securable)
          return_value.should include_only(node)
        end
      end

      context "when given a collection of Node instances" do
        it "returns a collection with the instances" do
          other_node = Node.new
          nodes      = [node, other_node]

          return_value = Node.normalize_collection(nodes)
          return_value.should include_only(*nodes)
        end
      end

      context "when given a collection of securable instances" do
        it "returns a collection with the instances" do
          other_node  = Node.new
          securables  = [stub(:ac_node => node),
                         stub(:ac_node => other_node)]

          return_value = Node.normalize_collection(securables)
          return_value.should include_only(node, other_node)
        end
      end
    end
  end
end
