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
      AccessControl.stub(:manager).and_return(manager)
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

      before do
        model.stub(:reflections => { :parent1 => reflection,
                                     :parent2 => reflection })
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
end
