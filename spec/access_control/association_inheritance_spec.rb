require 'spec_helper'

module AccessControl
  describe AssociationInheritance do
    include WithConstants

    let_constant(:record_class) do
      new_class(:Record, Sequel::Model) do
        set_dataset AccessControl.db[:records].filter(Sequel.~({record_id: nil}))
        include Inheritance

        def record= value
          self.record_id = value.id
          @record = value
        end

        def record
          @record
        end
      end
    end

    let_constant(:parent_class) do
      new_class(:Parent, Sequel::Model(:records)) do
        set_dataset AccessControl.db[:records].filter(record_id: nil)
        include Inheritance
      end
    end

    subject do
      AssociationInheritance.new(Record, :record_id, Parent.name, :record)
    end

    it "is initialized with a class, a key name and a securable type" do
      subject = AssociationInheritance.new(Record, :foo_id, "Foo", :foo)
      subject.model_class.should      == Record
      subject.key_name.should         == :foo_id
      subject.parent_type.should      == "Foo"
      subject.association_name.should == :foo
    end

    describe "equality" do
      it "is equal to other if the other's properties are the same" do
        other = AssociationInheritance.new(Record, :record_id,
                                           Parent.name, :record)
        subject.should == other
      end

      it "is not equal to other if the other's model is different" do
        other = AssociationInheritance.new(Class.new, :record_id,
                                           Parent.name, :record)
        subject.should_not == other
      end

      it "is not equal to other if the other's key is different" do
        other = AssociationInheritance.new(Record, :wrong_key,
                                           Parent.name, :record)
        subject.should_not == other
      end

      it "is not equal to other if the other's parent type is different" do
        other = AssociationInheritance.new(Record, :record_id,
                                           "WrongType", :record)
        subject.should_not == other
      end

      it "is not equal to other if the other's association is different" do
        other = AssociationInheritance.new(Record, :record_id,
                                           "WrongType", :wrong_association)
        subject.should_not == other
      end

      it "is not equal to other if the other is not a AssociationInheritance" do
        other = stub(:model_class => Record, :key_name => :record_id,
                     :parent_type => Parent.name)

        subject.should_not == other
      end
    end

    describe "#properties" do
      it "returns the inheritance's properties in a hash" do
        subject = AssociationInheritance.new(Record, :record_id,
                                             Parent.name, :record)
        subject.properties.should == {:record_type => 'Record',
                                      :key_name    => :record_id,
                                      :parent_type => Parent.name}
      end
    end

    def create_record(parent = nil)
      parent_id = parent && parent.id
      Record.create(:record_id => parent_id).tap do |record|
        nodes[record] = Node.store(:securable_type => Record.name,
                                   :securable_id   => record.id)
      end
    end

    def create_parent
      Parent.create.tap do |parent|
        nodes[parent] = Node.store(:securable_type => Parent.name,
                                   :securable_id   => parent.id)
      end
    end

    def nodes
      @nodes ||= Hash.new
    end

    describe "#relationships" do
      let!(:parent)     { create_parent}
      let!(:record)     { create_record(parent) }
      let(:parent_node) { nodes[parent] }
      let(:node)        { nodes[record] }

      it "contains an element for each parent-child relationship" do
        subject.relationships.count.should == 1
      end

      it "relates each child to its parent (by id), in parent-child form" do
        relationships = subject.relationships

        relationships.should include(:parent_id => parent_node.id,
                                     :child_id  => node.id)
      end

      context "when multiple records/nodes exists" do
        let!(:another_parent)     { create_parent}
        let!(:another_record)     { create_record(another_parent) }
        let(:another_parent_node) { nodes[another_parent] }
        let(:another_node)        { nodes[another_record] }

        it "contains an element for each parent-child relationship" do
          subject.relationships.count.should == 2
        end

        it "relates each child to its parent (by id), in parent-child form" do
          relationships = subject.relationships

          relationships.should include(:parent_id => parent_node.id,
                                       :child_id  => node.id)

          relationships.should include(:parent_id => another_parent_node.id,
                                       :child_id  => another_node.id)
        end

        context "and given a dataset to work on" do
          it "acts on the values of the dataset" do
            dataset = Record.naked.filter(Sequel[:records][:id] => record.id)
            relationships = subject.relationships(dataset)

            relationships.should include_only(:parent_id => parent_node.id,
                                              :child_id  => node.id)
          end
        end

        context "and given a collection of securables to work on" do
          it "acts on the values of the collection" do
            relationships = subject.relationships [record]

            relationships.should include_only(:parent_id => parent_node.id,
                                              :child_id  => node.id)

          end
        end
      end

      it "doesn't return relationships whose child has no id" do
        node.destroy

        relationships = subject.relationships
        relationships.should_not include(:parent_id => parent_node.id,
                                         :child_id  => nil)
      end

      it "doesn't return relationships whose parent has no id" do
        parent_node.destroy

        relationships = subject.relationships
        relationships.should_not include(:parent_id => nil,
                                         :child_id  => node.id)
      end

      context "when given a block" do
        it "yields the relationships to the block" do
          yielded = []
          subject.relationships do |relationship|
            yielded << [relationship[:parent_id], relationship[:child_id]]
          end

          yielded.should include [parent_node.id, node.id]
        end
      end

      context "when given a invalid collection argument" do
        it "raises ArgumentError" do
          lambda {
            subject.relationships record
          }.should raise_exception(ArgumentError)
        end
      end
    end

    describe "#parent_nodes_of" do
      let(:parent) { Parent.new }
      let(:node)   { stub }
      let(:record) { Record.new(:record => parent) }

      let(:manager) { stub }

      before do
        AccessControl.stub(:Node).with(parent).and_return(node)
        AccessControl.stub(:manager).and_return(manager)
        manager.stub(:trust).and_yield
      end

      it "returns the parent node of the securable record in an array" do
        subject.parent_nodes_of(record).should == [node]
      end

      it "gets the parent in a trusted way" do
        record.stub(:record).and_return(nil)
        manager.stub(:record).and_return(record)
        manager.stub(:parent).and_return(parent)
        manager.define_singleton_method(:trust) do |&block|
          record.stub(:record).and_return(parent)
          block.call
        end
        subject.parent_nodes_of(record).should == [node]
      end
    end
  end
end
