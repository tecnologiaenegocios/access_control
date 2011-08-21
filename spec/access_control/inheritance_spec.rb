require 'spec_helper'
require 'access_control/exceptions'
require 'access_control/restriction'

module AccessControl
  describe Inheritance do

    let(:model) { Class.new }
    let(:reflected_model) { Class.new }
    let(:manager) { mock('manager') }
    let(:reflection) { mock('reflection', :klass => reflected_model) }

    before do
      AccessControl.stub(:security_manager).and_return(manager)
      model.send(:include, Inheritance)
      model.stub(:find)
      model.stub(:reflections => { :parent => reflection })
      reflected_model.stub(:quoted_table_name => '`reflected_table`')
      reflected_model.stub(:primary_key => 'pk')
      manager.instance_eval do
        def without_query_restriction
          yield
        end
      end
    end

    describe ".inherits_permissions_from" do

      describe "when reflected model doesn't include Restriction" do

        it "complains" do
          lambda {
            model.inherits_permissions_from(:parent)
          }.should raise_error(InvalidInheritage)
        end

      end

      describe "when reflected model includes Restriction" do

        before do
          model.stub(:reflections => { :parent1 => reflection,
                                       :parent2 => reflection })
          reflected_model.send(:include, Restriction)
        end

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

    describe ".parent_models_and_options" do

      before do
        reflected_model.send(:include, Restriction)
      end

      describe "for each reflected model" do

        # The pk method of each record here is the primary key value of the
        # parent associated record.
        let(:record1) { mock('record 1', :id => "unimportant", :pk => 'id 1') }
        let(:record2) { mock('record 2', :id => "unimportant", :pk => 'id 2') }

        before do
          model.stub(:inherits_permissions_from).and_return([:parent])
          model.stub(:find).and_return([record1, record2])
        end

        it "runs without restriction" do
          manager.should_receive(:without_query_restriction)
          model.parent_models_and_options
        end

        it "finds all parent ids" do
          model.should_receive(:find).with(
            :all,
            :select => "DISTINCT `reflected_table`.pk",
            :joins => :parent
          ).and_return([record1, record2])
          model.parent_models_and_options
        end

        describe "for each item returned" do

          let(:returned) { model.parent_models_and_options.first }

          it "returns the reflected model as the first element" do
            returned.first.should == reflected_model
          end

          it "returns the association as the second element" do
            returned.second.should == :parent
          end

          describe "hash of find options as third element" do

            it "returns a hash containing a :select and a :conditions keys" do
              returned.third.keys.should include(:select)
              returned.third.keys.should include(:conditions)
              returned.third.keys.size.should == 2
            end

            it "selects only the primary key" do
              returned.third[:select].should == 'pk'
            end

            it "returns the primary keys in the conditions" do
              returned.third[:conditions].should == {'pk' => ['id 1', 'id 2']}
            end

          end

        end
      end

    end
  end
end
