require 'spec_helper'

module AccessControl
  describe Inheritance do

    let(:model) do
      klass = Class.new { include Inheritance }

      # Trick to make the model of each test have a different .name, so that
      # Inheritance won't treat models on different tests as the same.  Works
      # fine in subclasses, which naturally will have a different name from its
      # base class.

      klass.instance_eval do
        def name
          @name ||= Time.now.to_f.to_s
        end
      end

      klass
    end

    before(:all) do
      Inheritance.clear
    end

    after do
      Inheritance.clear
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
        AssociationInheritance.stub(:new).with(model, :parent_key, "Parent", :parent).
          and_return(association_inheritance)

        method_inheritance.stub(:relationships_of => [])
        association_inheritance.stub(:relationships_of => [])

        model.class_exec do
          inherits_permissions_from             :parent_method
          inherits_permissions_from_association :parent, :parent_key,
                                                :class_name => "Parent"
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

    describe ".parent_nodes_of" do
      let(:securable) { stub("Securable", :class => model) }

      let(:method_parent)      { stub("Method parent") }
      let(:association_parent) { stub("Association parent") }

      let(:method_inheritance)      { stub("Method inheritance") }
      let(:association_inheritance) { stub("Association inheritance") }

      before do
        MethodInheritance.stub(:new)
        MethodInheritance.stub(:new).with(model, :parent_method).
          and_return(method_inheritance)

        AssociationInheritance.stub(:new)
        AssociationInheritance.stub(:new).
          with(model, :parent_key, "Parent", :parent).
          and_return(association_inheritance)

        method_inheritance.stub(:parent_nodes_of => [])
        association_inheritance.stub(:parent_nodes_of => [])

        model.class_exec do
          inherits_permissions_from             :parent_method
          inherits_permissions_from_association :parent, :parent_key,
                                                :class_name => "Parent"
        end
      end

      it "returns the nodes retrieved by methods in the securable" do
        method_inheritance.stub(:parent_nodes_of).with(securable).
          and_return [method_parent]

        Inheritance.parent_nodes_of(securable).should \
          include_only(method_parent)
      end

      it "returns the nodes retrieved by associations in the securable" do
        association_inheritance.stub(:parent_nodes_of).with(securable).
          and_return [association_parent]

        Inheritance.parent_nodes_of(securable).should \
          include_only(association_parent)
      end

      it "returns the nodes of both method-based and association-based parents" do
        method_inheritance.stub(:parent_nodes_of).with(securable).
          and_return [method_parent]
        association_inheritance.stub(:parent_nodes_of).with(securable).
          and_return [association_parent]

        parents = [method_parent, association_parent]
        Inheritance.parent_nodes_of(securable).should == parents
      end

      it "removes duplicates" do
        same_parent = stub

        method_inheritance.stub(:parent_nodes_of).with(securable).
          and_return [same_parent]
        association_inheritance.stub(:parent_nodes_of).with(securable).
          and_return [same_parent]

        Inheritance.parent_nodes_of(securable).should include_only(same_parent)
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

    describe ".inherits_permissions_from_association" do
      it "raises ArgumentError if not given a class name" do
        lambda {
          model.inherits_permissions_from_association('foo', 'foo_id')
        }.should raise_exception(ArgumentError)
      end

      it "returns a AssociationInheritance" do
        inheritance = model.inherits_permissions_from_association('foo', 'foo_id',
                                                                  :class_name => "Foo")
        inheritance.should be_kind_of(AssociationInheritance)
      end

      it "stores the information from the class on the Inheritance module" do
        lambda {
          model.inherits_permissions_from_association('foo', 'foo_id',
                                                      :class_name => "Foo")
        }.should change(Inheritance.inheritances_of(model), :count).by(1)
      end

      it "stores the returned inheritance on the Inheritance module" do
        inheritance =
          model.inherits_permissions_from_association('foo', 'foo_id',
                                                      :class_name => "Foo")
        Inheritance.inheritances_of(model).should include(inheritance)
      end

      it "doesn't add a new inheritance if a equivalent exists" do
        model.inherits_permissions_from_association('foo', 'foo_id',
                                                    :class_name => "Foo")

        lambda {
          model.inherits_permissions_from_association('foo', 'foo_id',
                                                      :class_name => "Foo")
        }.should_not change(Inheritance.inheritances_of(model), :count)
      end

      it "creates the inheritance with the correct parameters" do
        model.inherits_permissions_from_association('foo', 'foo_id',
                                                    :class_name => "Foo")
        inheritance = Inheritance.inheritances_of(model).first

        inheritance.model_class.name.should == model.name
        inheritance.key_name.should         == :foo_id
        inheritance.parent_type.should      == "Foo"
        inheritance.association_name.should == :foo
      end
    end

    describe ".inheritances_of" do
      let!(:inheritance) do
        model.inherits_permissions_from_association('foo', "foo_id",
                                                    :class_name => "Foo")
      end

      it "finds inheritances correctly if given a class" do
        Inheritance.inheritances_of(model).should include(inheritance)
      end

      context "working with subclasses" do
        let(:submodel) { Class.new(model) }

        context "when no inheritance was defined for the subclass" do
          it "gets the inheritances from parent class" do
            Inheritance.inheritances_of(submodel).should include(inheritance)
          end
        end

        context "when an inheritance was defined in the subclass" do
          let!(:submodel_inheritance) do
            submodel.inherits_permissions_from_association('bar', "bar_id",
                                                           :class_name => "Bar")
          end

          it "overrides the inheritance chain" do
            Inheritance.inheritances_of(submodel).should_not include(inheritance)
            Inheritance.inheritances_of(submodel).should include(submodel_inheritance)
          end
        end
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

    describe ".clear" do
      before do
        model.inherits_permissions_from(:foo)
        Inheritance.clear
      end

      it "clears inheritance" do
        Inheritance.inheritances_of(model).should be_empty
      end
    end
  end
end
