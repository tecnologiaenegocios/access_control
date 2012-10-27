require 'spec_helper'

module AccessControl
  describe MethodInheritance do
    let(:model) { Class.new }
    let(:orm)   { stub }

    def ids
      @ids ||= 1.to_enum(:upto, Float::INFINITY)
    end

    def nodes
      @nodes ||= Hash.new do |hash, record|
        node_id = ids.next
        hash[record] = stub("#{node_id} node", :id => node_id)
      end
    end

    def stub_record(stubs = {})
      record_id = stubs[:id] ||= ids.next
      stub("Record #{record_id}", stubs)
    end

    it "is initialized with a class and a method name" do
      subject = MethodInheritance.new(model, :foobar)
      subject.model_class.should == model
      subject.method_name.should == :foobar
    end

    before do
      AccessControl.stub(:Node) { |record| nodes[record] }
      ORM.stub(:adapt_class).with(model).and_return(orm)
      model.stub(:name => 'RecordType')
      orm.stub(:values => [record])
    end

    let(:parent)      { stub_record }
    let(:record)      { stub_record(:parent => parent) }
    let(:parent_node) { nodes[parent] }
    let(:node)        { nodes[record] }

    subject { MethodInheritance.new(model, :parent) }

    describe "equality" do
      it "is equal to other if the other's model and method are the same" do
        other = MethodInheritance.new(model, :parent)
        subject.should == other
      end

      it "is not equal to other if the other's model is different" do
        other_model = Class.new
        ORM.stub(:adapt_class).with(other_model).and_return(stub())
        other = MethodInheritance.new(other_model, :parent)
        subject.should_not == other
      end

      it "is not equal to other if the other's method is different" do
        other = MethodInheritance.new(model, :grandparent)
        subject.should_not == other
      end

      it "is not equal to other if the other is not a MethodInheritance" do
        other = stub(:model_class => model, :method_name => :parent)
        subject.should_not == other
      end
    end

    describe "#properties" do
      it "returns the inheritance's properties in a hash" do
        subject = MethodInheritance.new(model, :parent)
        subject.properties.should == {:record_type => 'RecordType',
                                      :method_name => :parent}
      end
    end

    describe "#relationships" do
      let(:another_parent)      { stub_record}
      let(:another_record)      { stub_record(:parent => another_parent) }
      let(:another_node)        { nodes[another_record] }
      let(:another_parent_node) { nodes[another_parent] }

      before { orm.stub(:values => [record, another_record]) }

      it "contains an element for each parent-child relationship" do
        subject.relationships.count.should == 2
      end

      it "relates each child to its parent (by id), in a parent-child array" do
        relationships = subject.relationships

        relationships.should include(:parent_id => parent_node.id,
                                     :child_id  => node.id)

        relationships.should include(:parent_id => another_parent_node.id,
                                     :child_id  => another_node.id)
      end

      it "doesn't return relationships whose child has no id" do
        another_node.stub(:id => nil)

        relationships = subject.relationships
        relationships.should_not include(:parent_id => another_parent_node.id,
                                         :child_id  => another_node.id)
      end

      it "doesn't return relationships whose parent has no id" do
        another_parent_node.stub(:id => nil)

        relationships = subject.relationships
        relationships.should_not include(:parent_id => another_parent_node.id,
                                         :child_id  => another_node.id)
      end

      it "doesn't try to fetch the node of null parents" do
        another_record.stub(:parent => nil)
        AccessControl.should_not_receive(:Node).with(nil)

        subject.relationships.to_a
      end

      context "when given a block" do
        it "yields the relationships to the block" do
          yielded = []
          subject.relationships do |relationship|
            yielded << relationship
          end

          yielded.should include(:parent_id => parent_node.id,
                                 :child_id  => node.id)

          yielded.should include(:parent_id => another_parent_node.id,
                                 :child_id  => another_node.id)
        end
      end

      context "when given a collection" do
        it "acts on the values of the collection" do
          relationships = subject.relationships([record])

          relationships.should include_only(:parent_id => parent_node.id,
                                            :child_id  => node.id)
        end
      end
    end

    describe "#relationships_of" do
      it "has the same effect as calling #relationships" do
        subject.relationships.to_a.should == subject.relationships_of.to_a
      end
    end

    describe "#parent_nodes_of" do
      context "single record" do
        let(:parent) { stub_record }
        let(:node)   { nodes[parent] }
        let(:record) { stub_record(:parent => parent) }

        subject { MethodInheritance.new(model, :parent) }

        it "returns the parent node of the securable record in an array" do
          subject.parent_nodes_of(record).should == [node]
        end
      end

      context "collection" do
        let(:parent1) { stub_record }
        let(:parent2) { stub_record }
        let(:node1)   { nodes[parent1] }
        let(:node2)   { nodes[parent2] }
        let(:record)  { stub_record(:parents => [parent1, parent2]) }

        subject { MethodInheritance.new(model, :parents) }

        it "returns the parent nodes of the securable record" do
          subject.parent_nodes_of(record).should include_only(node1, node2)
        end
      end
    end

    describe "when assigned to a method that returns a collection" do
      subject { MethodInheritance.new(model, :parents) }

      let(:parent1) { stub_record }
      let(:parent2) { stub_record }

      let(:record)  { stub_record(:parents => [parent1, parent2]) }

      specify "#relationships returns a flat collection of all the parents" do
        relationships = subject.relationships
        relationships.should include(:parent_id => nodes[parent1].id,
                                     :child_id  => nodes[record].id)

        relationships.should include(:parent_id => nodes[parent2].id,
                                     :child_id  => nodes[record].id)
      end
    end
  end
end
