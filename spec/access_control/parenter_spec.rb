require 'spec_helper'
require 'access_control/parenter'

module AccessControl
  describe Parenter do

    let(:model) do
      Class.new(Struct.new(:parent1, :parent2, :node)) do
        include Inheritance
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

      before(:all) do
        model.class_exec do
          inherits_permissions_from :parent1, :parent2
        end
      end

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

    describe "when the record has inheritance" do

      let(:global_record) { AccessControl::GlobalRecord.instance }
      subject { Parenter.new(record) }

      let(:parents) do
        Hash.new do |hash, index|
          hash[index] = model.new
        end
      end

      before do
        model.inherits_permissions_from [:parent1, :parent2]
      end

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

      context "when the record has no parents" do
        before do
          record.stub(:parent1 => nil)
          record.stub(:parent2 => nil)
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

  end
end
