require 'spec_helper'

module AccessControl
  describe Inheritance do

    def unique_model_name
      Time.now.to_f.to_s
    end

    let(:model) do
      klass = Class.new { include Inheritance }

      # Trick to make the model of each test have a different .name, so that
      # Inheritance won't treat models on differents tests as the same

      klass.class_exec(unique_model_name) do |name|
        define_singleton_method(:name) { name }
      end

      klass
    end


    describe ".parent_node_ids_of" do
      let(:securable) { stub("Securable", :class => model) }

      let(:method_parent_id)      { stub("Method parent id") }
      let(:association_parent_id) { stub("Association parent id") }

      let(:method_inheritance)      { stub("Method inheritance") }
      let(:association_inheritance) { stub("Association inheritance") }

      before do
        MethodInheritance.stub(:new)
        MethodInheritance.stub(:new).with(model, :parent_method).
          and_return(method_inheritance)

        AssociationInheritance.stub(:new)
        AssociationInheritance.stub(:new).with(model, :parent_key, "Parent").
          and_return(association_inheritance)

        method_inheritance.stub(:relationships_of => [])
        association_inheritance.stub(:relationships_of => [])

        model.class_exec do
          inherits_permissions_from     :parent_method
          inherits_permissions_from_key :parent_key, :class_name => "Parent"
        end
      end

      it "returns the ids of nodes retrieved by methods in the securable" do
        method_inheritance.stub(:relationships_of).with([securable]).
          and_return [ {:parent_id => method_parent_id} ]

        Inheritance.parent_node_ids_of(securable).should include(method_parent_id)
      end

      it "returns the ids of nodes retrieved by FKs in the securable" do
        association_inheritance.stub(:relationships_of).with([securable]).
          and_return [ {:parent_id => association_parent_id} ]

        Inheritance.parent_node_ids_of(securable).should include(association_parent_id)
      end

      it "returns the ids of both method-based and FK-based parents" do
        method_inheritance.stub(:relationships_of).with([securable]).
          and_return [ {:parent_id => method_parent_id} ]
        association_inheritance.stub(:relationships_of).with([securable]).
          and_return [ {:parent_id => association_parent_id} ]

        parents = [method_parent_id, association_parent_id]
        Inheritance.parent_node_ids_of(securable).should include_only(*parents)
      end

      it "removes duplicates" do
        same_parent_id = 666

        method_inheritance.stub(:relationships_of).with([securable]).
          and_return [ {:parent_id => same_parent_id} ]
        association_inheritance.stub(:relationships_of).with([securable]).
          and_return [ {:parent_id => same_parent_id} ]

        Inheritance.parent_node_ids_of(securable).should include_only(same_parent_id)
      end
    end

    describe ".inherits_permissions_from" do
      it "returns a MethodInheritance" do
        inheritance = model.inherits_permissions_from(:foo)
        inheritance.should be_kind_of(MethodInheritance)
      end

      it "creates a new inheritance for the class on the Inheritance module" do
        lambda {
          model.inherits_permissions_from(:foo)
        }.should change(Inheritance.inheritances_of(model), :count).by(1)
      end

      it "stores the returned inheritance on the Inheritance module" do
        inheritance = model.inherits_permissions_from(:foo)
        Inheritance.inheritances_of(model).should include(inheritance)
      end

      it "doesn't add a new inheritance if a equivalent exists" do
        model.inherits_permissions_from(:foo)

        lambda {
          model.inherits_permissions_from(:foo)
        }.should_not change(Inheritance.inheritances_of(model), :count)
      end

      context "when given multiple methods" do
        it "creates one inheritance for each of them" do
          lambda {
            model.inherits_permissions_from(:foo, :bar)
          }.should change(Inheritance.inheritances_of(model), :count).by(2)
        end

        it "returns a collection of the created inheritances" do
          return_values = model.inherits_permissions_from(:foo, :bar)
          return_values.each do |return_value|
            return_value.should be_kind_of(MethodInheritance)
          end
        end

        it "stores the returned inheritances on the Inheritance module" do
          created_inheritances = model.inherits_permissions_from(:foo, :bar)
          stored_inheritances = Inheritance.inheritances_of(model)

          stored_inheritances.should include(*created_inheritances)
        end

        it "doesn't add a new inheritance if a equivalent exists" do
          model.inherits_permissions_from(:foo)

          lambda {
            model.inherits_permissions_from(:foo, :bar)
          }.should change(Inheritance.inheritances_of(model), :count).by(1)
        end
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

      it "creates the inheritance with the correct parameters" do
        model.inherits_permissions_from_key('foo_id', :class_name => "Foo")
        inheritance = Inheritance.inheritances_of(model).first

        inheritance.model_class.name.should == model.name
        inheritance.key_name.should         == :foo_id
        inheritance.parent_type.should      == "Foo"
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
