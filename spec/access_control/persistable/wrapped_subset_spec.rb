require 'spec_helper'

describe AccessControl::Persistable::WrappedSubset do
  let(:original_subset) { Array.new }
  let(:persistable_model) { stub }
  subject do
    AccessControl::Persistable::WrappedSubset.new(persistable_model,
                                                  original_subset) 
  end

  it { should be_kind_of(Enumerable) }


  describe "wrapped methods" do
    let(:wrapped_item)  { stub("Wrapped item") }
    let(:original_item) { stub("Original item") }

    before do
      original_subset << original_item
      persistable_model.stub(:wrap).with(original_item).
        and_return(wrapped_item)
    end

    describe "#all" do
      it "returns an Array of all the wrapped items" do
        subject.all.should == [wrapped_item]
      end
    end

    describe "#each" do
      it "yields each item of the original subset wrapped in a persistable" do
        yielded_items = []
        subject.each do |yielded_item|
          yielded_items << yielded_item
        end

        yielded_items.should == [wrapped_item]
      end
    end

    describe "#to_a" do
      it "returns a collection of all the wrapped items" do
        subject.to_a.should include_only(wrapped_item)
      end
    end

    describe "#scoped_column" do
      let(:scoped_column)       { Array.new }
      let(:original_scope_item) { stub("Original scope item") }
      let(:wrapped_scope_item)  { stub("Wrapped scope item") }

      before do
        scoped_column << original_scope_item
        persistable_model.stub(:wrap).with(original_scope_item).
          and_return(wrapped_scope_item)

        original_subset.stub(:scoped_column).with(:column).
          and_return(scoped_column)
      end

      it "returns a wrapper scope" do
        wrapped_scope = subject.scoped_column(:column)
        wrapped_scope.should be_kind_of(
          AccessControl::Persistable::WrappedSubset
        )
      end

      it "returns an object that has the scope wrapped items" do
        wrapped_scope = subject.scoped_column(:column)
        wrapped_scope.should include_only(wrapped_scope_item)
      end
    end
  end

  delegated_methods = [:count, :any?, :empty?, :sql]

  delegated_methods.each do |method_name|
    it "delegates ##{method_name} to the original subset" do
      original_value = stub
      original_subset.stub(method_name).and_return(original_value)

      subject.public_send(method_name).should == original_value
    end
  end
end
