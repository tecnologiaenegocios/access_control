require 'access_control/inheritance'
require 'support/matchers/recognize'

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

    describe ".recognizes?" do
      let(:inheritance_class) { Class.new { include Inheritance } }
      let(:non_inheritance_class) { Class.new }

      context "when the argument is a class" do
        it "returns true when it includes Inheritance" do
          Inheritance.should recognize inheritance_class
        end

        it "returns false when it doesn't include Inheritance" do
          Inheritance.should_not recognize non_inheritance_class
        end
      end

      context "when the argument is not a class" do
        it "returns true when its Class includes Inheritance" do
          object = inheritance_class.new
          Inheritance.should recognize object
        end

        it "returns false when its Class doesn't include Inheritance" do
          object = non_inheritance_class.new
          Inheritance.should_not recognize object
        end

        it "returns false if Inheritance was injected directly in the object" do
          object = Object.new.extend(Inheritance)
          Inheritance.should_not recognize object
        end
      end
    end

  end
end
