require 'spec_helper'

module AccessControl
  describe ModelSecurity do

    describe ModelSecurity::ClassMethods do

      describe "protection of methods" do

        let(:test_object) do
          object = Class.new
          object.extend(ModelSecurity::ClassMethods)
          object
        end

        before do
          test_object.permissions_for_methods.delete(:some_method)
        end

        it "is managed through #protect" do
          test_object.protect(:some_method, :with => 'some permission')
          test_object.permissions_for(:some_method).should == Set.new([
            'some permission'
          ])
        end

        it "always combines permissions" do
          test_object.protect(:some_method, :with => 'some permission')
          test_object.protect(:some_method, :with => 'some other permission')
          test_object.permissions_for(:some_method).should == Set.new([
            'some permission', 'some other permission'
          ])
        end

        it "accepts an array of permissions" do
          test_object.protect(:some_method,
                              :with => ['some permission', 'some other'])
          test_object.permissions_for(:some_method).should == Set.new([
            'some permission', 'some other'
          ])
        end

      end

      describe "parent association" do

        let(:test_object) do
          object = Class.new
          object.extend(ModelSecurity::ClassMethods)
          object
        end

        it "can be defined" do
          test_object.parent_association(:test)
          test_object.parent_association.should == :test
        end

      end
    end

    describe ModelSecurity::InstanceMethods do

      let(:model_klass) do
        klass = Class.new(ActiveRecord::Base)
        klass.class_eval do
          def self.columns
            []
          end
        end
        klass
      end

      it "is securable" do
        model_klass.new.securable?.should be_true
      end

      it "extends the class with the class methods" do
        model_klass.should_receive(:extend).with(ModelSecurity::ClassMethods)
        model_klass.send(:include, ModelSecurity::InstanceMethods)
      end

      it "makes available the has_one association to ac_node" do
        model_klass.should_receive(:has_one).with(
          :ac_node, :as => :securable,
          :class_name => ::AccessControl::Model::Node.name
        )
        model_klass.send(:include, ModelSecurity::InstanceMethods)
      end

      describe "parent node list" do

        before do
          model_klass.send(:include, ModelSecurity::InstanceMethods)
        end

        it "is empty by default" do
          model_klass.new.parents.should be_empty
        end

        it "will be the parent association if defined and collection" do
          model_klass.class_eval do
            parent_association :parent_assoc
            def parent_assoc
              ['some parents']
            end
          end
          model_klass.new.parents.should == ['some parents']
        end

        it "will be an array of one element if the parent assoc is single" do
          model_klass.class_eval do
            parent_association :parent_assoc
            def parent_assoc
              'some parent'
            end
          end
          model_klass.new.parents.should == ['some parent']
        end

      end

    end

    describe "node management" do

      let(:model_klass) do
        klass = Class.new(ActiveRecord::Base)
        klass.class_eval do
          def self.columns
            []
          end
          def create_without_callbacks
            true
          end
        end
        klass
      end

      it "creates one node with the parents' nodes" do
        parent_node1 = stub('parent node1')
        parent_node2 = stub('parent node2')
        parent1 = stub('parent1', :ac_node => parent_node1)
        parent2 = stub('parent2', :ac_node => parent_node2)
        record = model_klass.new
        record.stub!(:parents).and_return([parent1, parent2])
        ::AccessControl::Model::Node.should_receive(:create!).
          with(:securable => record, :parents => [parent_node1, parent_node2])
        record.save
      end

      it "doesn't create any node if the object is not securable" do
        parent_node1 = stub('parent node1')
        parent1 = stub('parent1', :ac_node => parent_node1)
        record = model_klass.new
        record.stub!(:parents).and_return([parent1])
        record.stub!(:securable?).and_return(false)
        ::AccessControl::Model::Node.should_not_receive(:create!)
        record.save
      end

      it "updates parents of the node" do
        parent_node1 = stub('parent node1')
        parent_node2 = stub('parent node2')
        parent_node3 = stub('parent node3')
        parent_node4 = stub('parent node4')

        node = mock('node', :parents => [parent_node1, parent_node3])

        new_parent1 = stub('new parent1', :ac_node => parent_node2)
        new_parent2 = stub('new parent2', :ac_node => parent_node4)

        record = model_klass.new
        record.stub!(:new_record?).and_return(false)
        record.stub!(:id).and_return(1)
        record.stub!(:ac_node).and_return(node)
        record.stub!(:parents).and_return([new_parent1, new_parent2])

        node.should_receive(:parents=).with([parent_node2, parent_node4])
        record.save
      end

    end

  end
end
