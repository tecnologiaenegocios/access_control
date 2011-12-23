require 'spec_helper'

module AccessControl
  describe Node::WrapperScope do

    let(:original_scope) { Array.new }
    subject { Node::WrapperScope.new(original_scope) }

    it "is an enumerable" do
      subject.should be_kind_of Enumerable
    end

    describe "#each" do
      let(:wrapped_item) { stub }
      let(:original_item) { stub }

      before do
        original_scope << original_item
        Node.stub(:wrap).with(original_item).and_return(wrapped_item)
      end

      it "yields each item of the original scope wrapped in a Node" do
        yielded_items = []
        subject.each do |yielded_item|
          yielded_items << yielded_item
        end

        yielded_items.should == [wrapped_item]
      end

      it "returns a collection of all the wrapped items" do
        subject.each.should include(wrapped_item)
      end
    end

    describe "#all" do
      let(:wrapped_item) { stub }
      let(:original_item) { stub }

      before do
        original_scope << original_item
        Node.stub(:wrap).with(original_item).and_return(wrapped_item)
      end

      it "returns a collection of all the wrapped items" do
        subject.all.should include(wrapped_item)
      end
    end

    delegated_methods = [:count, :any?, :empty?]

    delegated_methods.each do |method_name|
      it "delegates the '#{method_name}' method to the original scope" do
        original_value = stub
        original_scope.stub(method_name).and_return(original_value)

        subject.public_send(method_name).should == original_value
      end
    end

  end
end
