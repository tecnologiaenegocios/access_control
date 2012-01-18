require 'spec_helper'

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

    describe ".inherits_permissions_from_key" do
      it "raises ArgumentError if not given a column name and a class name" do
        lambda {
          model.inherits_permissions_from_key('foo_id')
        }.should raise_exception(ArgumentError)
      end

      it "returns a AssociationInheritance" do
        inheritance = model.inherits_permissions_from_key('foo_id', :class_name => "Foo")
        inheritance.should be_kind_of(AssociationInheritance)
      end

      it "stores the information from the class on the Inheritance module" do
        lambda {
          model.inherits_permissions_from_key('foo_id', :class_name => "Foo")
        }.should change(Inheritance.inheritances_of(model), :count).by(1)
      end

      it "stores the returned inheritance on the Inheritance module" do
        inheritance =
          model.inherits_permissions_from_key('foo_id', :class_name => "Foo")
        Inheritance.inheritances_of(model).should include(inheritance)
      end

      it "doesn't add a new inheritance if a equivalent exists" do
        model.inherits_permissions_from_key('foo_id', :class_name => "Foo")

        lambda {
          model.inherits_permissions_from_key('foo_id', :class_name => "Foo")
        }.should_not change(Inheritance.inheritances_of(model), :count)
      end
    end

    describe ".inheritances_of" do
      let!(:inheritance) do
        model.inherits_permissions_from_key("foo_id", :class_name => "Foo")
      end

      it "finds inheritances correctly if given a class" do
        Inheritance.inheritances_of(model).should include(inheritance)
      end

      it "finds inheritances correctly if given a class name" do
        Inheritance.inheritances_of(model.name).should include(inheritance)
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
