# vim: fdm=marker

require 'spec_helper'
require 'access_control/parenter'

module AccessControl
  describe Parenter do

    # Verbose setup {{{
    let(:model) do
      Class.new(Struct.new(:parent1, :parent2, :node)) do
        include Inheritance
        inherits_permissions_from :parent1, :parent2
      end
    end

    let(:node_class) do
      Class.new do
        attr_reader :name, :index
        def initialize(index)
          @index = index
          @name  = "Node #{index}"
        end
      end
    end

    let(:nodes) do
      Hash.new do |hash, index|
        hash[index] = node_class.new(index)
      end
    end

    let(:parents) do
      Hash.new do |hash, index|
        hash[index] = model.new
      end
    end

    before do
      AccessControl.stub(:Node) do |obj|
        obj.kind_of?(node_class) ? obj : obj.node
      end
    end
    # }}}

    let(:root_node) { nodes[0] }
    let(:record) { model.new }

    it "takes a record as a the only obligatory parameter" do
      lambda {
        Parenter.new(record)
      }.should_not raise_exception(ArgumentError)
    end

    it "complains if the record is not an Inheritance" do
      non_inheritance_record = stub

      lambda {
        Parenter.new(non_inheritance_record, [:foo, :bar])
      }.should raise_exception(InvalidInheritage)
    end

    it "may take a list of associations as the second argument" do
      lambda {
        Parenter.new(record, [:foo, :bar])
      }.should_not raise_exception(ArgumentError)
    end

    it "may use the record's class associations as default" do
      model.inherits_permissions_from [:foo, :bar]

      lambda {
        Parenter.new(record)
      }.should_not raise_exception(ArgumentError)
    end

    describe "the convenience method Parenter.parents_of" do
      it "may take a list of associations as the second argument" do
        lambda {
          Parenter.parents_of(record, [:parent1, :parent2])
        }.should_not raise_exception(ArgumentError)
      end

      it "may use the record's class associations as default" do
        lambda {
          Parenter.parents_of(record)
        }.should_not raise_exception(ArgumentError)
      end

      it "works in the same way as Parenter.new(foo).parent_records" do
        Parenter.parents_of(record).should ==
          Parenter.new(record).parent_records
      end
    end

    describe "the convenicence method Parenter.parent_nodes_of" do
      before do
        record.parent1 = parents[1]
      end

      it "may take a list of associations as the second argument" do
        lambda {
          Parenter.parent_nodes_of(record, [:parent1, :parent2])
        }.should_not raise_exception(ArgumentError)
      end

      it "may use the record's class associations as default" do
        lambda {
          Parenter.parent_nodes_of(record)
        }.should_not raise_exception(ArgumentError)
      end

      it "works in the same way as Parenter.new(foo).parent_nodes" do
        Parenter.parent_nodes_of(record).should ==
          Parenter.new(record).parent_nodes
      end
    end

    describe "when the record has inheritance" do

      let(:global_record) { AccessControl::GlobalRecord.instance }
      subject { Parenter.new(record) }

      describe "#parent_records" do

        it "gets the record parents" do
          record.parent1 = parents[1]
          record.parent2 = parents[2]

          subject.parent_records.should == Set[parents[1], parents[2]]
        end

        it "doesn't break if the some of the parents are nil" do
          record.parent1 = parents[1]
          record.parent2 = nil

          subject.parent_records.should == Set[parents[1]]
        end

        it "merges collection associations" do
          parents[3] = [parents[1], parents[2]]

          record.parent1 = parents[3]
          record.parent2 = parents[4]

          subject.parent_records.should == Set[parents[1], parents[2], parents[4]]
        end

        context "when the record has no parents" do
          before do
            record.parent1 = nil
            record.parent2 = nil
          end

          it "returns the global record by default" do
            subject.parent_records.should == Set[global_record]
          end

          it "may receive a flag to not include the global record" do
            returned_set = subject.parent_records(false)
            returned_set.should be_empty
          end
        end
      end

      describe "#parent_nodes" do

        before do
          record.parent1 = parents[1]
          record.parent2 = parents[2]
        end

        it "includes the immediate parent node of a record" do
          parents[1].node = parents[2].node = root_node

          parenter = Parenter.new record
          result   =  parenter.parent_nodes

          result.should include root_node
        end

        it "includes all the immediate parent nodes of a record" do
          parents[1].node = nodes[1]
          parents[2].node = nodes[2]

          parenter = Parenter.new record
          result   =  parenter.parent_nodes

          result.should include(nodes[1], nodes[2])
        end

        it "doesn't include 'nil' values" do
          parents[1].node = nodes[1]
          parents[2].node = nil

          parenter = Parenter.new record
          result   =  parenter.parent_nodes

          result.should_not include nil
        end

        context "when the record has no parents" do
          it "returns the global node" do
            record.parent1 = nil
            record.parent2 = nil

            AccessControl.stub(:Node) do |obj|
              root_node if obj == GlobalRecord.instance
            end

            parenter = Parenter.new record
            result   =  parenter.parent_nodes

            result.should == Set[root_node]
          end
        end
      end

      describe "#ancestor_records" do
        let(:first_parent)  { parents[1] }
        let(:second_parent) { parents[2] }

        let(:first_ancestor)  { parents[3] }
        let(:second_ancestor) { parents[4] }

        before do
          record.parent1 = first_parent
          record.parent2 = second_parent

          first_parent.parent1  = first_ancestor
          second_parent.parent2 = second_ancestor
        end

        it "contains the immediate parents of the record" do
          parenter = Parenter.new(record)
          parenter.ancestor_records.should include first_parent, second_parent
        end

        it "contains the grandparents of the record" do
          parenter = Parenter.new(record)
          parenter.ancestor_records.
            should include first_ancestor, second_ancestor
        end

        it "works with arbritarily big hierarchies" do
          parent_chain = []

          1.upto(10) do |order|
            parent_chain << (parents[order].parent1 = parents[order+1])
          end

          parenter = Parenter.new(record)
          parenter.ancestor_records.should include *parent_chain
        end

        it "doesn't include nil parents" do
          record.parent2 = nil

          parenter = Parenter.new(record)
          parenter.ancestor_records.should_not include nil
        end

        it "doesn't include nil grandparents" do
          first_parent.parent1 = nil

          parenter = Parenter.new(record)
          parenter.ancestor_records.should_not include nil
        end
      end
    end

  end
end
