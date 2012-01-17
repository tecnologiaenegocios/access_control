require 'spec_helper'

module AccessControl
  describe MethodInheritance do
    let(:model) { Class.new }

    def ids
      @ids ||= 1.to_enum(:upto, Float::INFINITY)
    end

    it "is initialized with a class and a method name" do
      subject = MethodInheritance.new(model, :foobar)
      subject.model_class.should == model
      subject.method_name.should == :foobar
    end

    before do
      AccessControl.stub(:Node) { |obj| obj.node }
      model.stub(:all => [record])
    end

    let(:parent_node)         { stub(:id => ids.next) }
    let(:parent)              { stub(:node => parent_node) }
    let(:node)                { stub(:id => ids.next) }
    let(:record)              { stub(:parent => parent, :node => node) }

    before { model.stub(:all => [record]) }

    subject { MethodInheritance.new(model, :parent) }

    describe "#relationships" do
      let(:another_parent_node) { stub(:id => ids.next) }
      let(:another_node)        { stub(:id => ids.next) }
      let(:another_parent)      { stub(:node => another_parent_node) }
      let(:another_record)      { stub(:parent => another_parent,
                                       :node => another_node) }

      before { model.stub(:all => [record, another_record]) }

      it "contains an element for each parent-child relationship" do
        subject.relationships.count.should == 2
      end

      it "relates each child to its parent (by id), in a parent-child array" do
        relationships = subject.relationships

        relationships.should include [parent_node.id, node.id]
        relationships.should include [another_parent_node.id, another_node.id]
      end

      it "doesn't return relationships whose child has no id" do
        another_node.stub(:id => nil)

        relationships = subject.relationships
        relationships.should_not include [another_parent_node.id, another_node.id]
      end

      it "doesn't return relationships whose parent has no id" do
        another_parent_node.stub(:id => nil)

        relationships = subject.relationships
        relationships.should_not include [another_parent_node.id, another_node.id]
      end

      it "doesn't try to fetch the node of null parents" do
        another_record.stub(:parent => nil)
        AccessControl.should_not_receive(:Node).with(nil)

        subject.relationships.to_a
      end

      context "when given a block" do
        it "yields the relationships to the block" do
          yielded = []
          subject.relationships do |parent_id, node_id|
            yielded << [parent_id, node_id]
          end

          yielded.should include [parent_node.id, node.id]
          yielded.should include [another_parent_node.id, another_node.id]
        end
      end

      context "when given a collection" do
        it "acts on the values of the collection" do
          relationships = subject.relationships([record])
          relationships.should include_only [parent_node.id, node.id]
        end
      end
    end

    describe "#relationships_of" do
      it "has the same effect as calling #relationships" do
        subject.relationships.should == subject.relationships_of
      end
    end

  end
end
