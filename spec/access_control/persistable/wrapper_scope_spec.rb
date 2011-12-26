require 'spec_helper'

module AccessControl::Persistable
  describe WrapperScope do
    let(:original_scope) { Array.new }
    let(:persistable_model) { stub }
    subject { WrapperScope.new(persistable_model, original_scope) }

    it { should be_kind_of(Enumerable) }

    describe "#each" do
      let(:wrapped_item) { stub }
      let(:original_item) { stub }

      before do
        original_scope << original_item
        persistable_model.stub(:wrap).with(original_item).
          and_return(wrapped_item)
      end

      it "yields each item of the original scope wrapped in a persistable" do
        yielded_items = []
        subject.each do |yielded_item|
          yielded_items << yielded_item
        end

        yielded_items.should == [wrapped_item]
      end

      it "returns a collection of all the wrapped items" do
        subject.each.should == [wrapped_item]
      end
    end

    describe "#all" do
      let(:wrapped_item) { stub }
      let(:original_item) { stub }

      before do
        original_scope << original_item
        persistable_model.stub(:wrap).with(original_item).
          and_return(wrapped_item)
      end

      it "returns a collection of all the wrapped items" do
        subject.all.should == [wrapped_item]
      end
    end

    delegated_methods = [:count, :any?, :empty?]

    delegated_methods.each do |method_name|
      it "delegates ##{method_name} to the original scope" do
        original_value = stub
        original_scope.stub(method_name).and_return(original_value)

        subject.public_send(method_name).should == original_value
      end
    end
  end
end
