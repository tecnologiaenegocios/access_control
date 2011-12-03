require 'spec_helper'
require 'access_control/exceptions'
require 'access_control/restriction'

module AccessControl
  describe Inheritance do

    let(:model) { Class.new }

    before do
      model.send(:include, Inheritance)
    end

    describe ".inherits_permissions_from" do

      it "accepts a list of associations" do
        model.inherits_permissions_from(:parent1, :parent2)
        model.inherits_permissions_from.should == [:parent1, :parent2]
      end

      it "accepts strings, but always returns back symbols" do
        model.inherits_permissions_from('parent1', 'parent2')
        model.inherits_permissions_from.should == [:parent1, :parent2]
      end

      it "returns an empty array if nothing is defined" do
        model.inherits_permissions_from.should == []
      end

      it "accepts an array as a single argument" do
        model.inherits_permissions_from([:parent1, :parent2])
        model.inherits_permissions_from.should == [:parent1, :parent2]
      end

    end

  end
end
