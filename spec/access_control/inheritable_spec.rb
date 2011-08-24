require 'spec_helper'
require 'access_control/inheritable'
require 'access_control/inheritance'

module AccessControl
  describe Inheritable do

    # An Inheritable object takes a model and a set of permissions and gets the
    # ids of the model's table to which those permissions are propagated from
    # parent models.

    let(:model) { Class.new }
    let(:reflected_model) { Class.new }

    before do
      model.stub(:named_scope)
      model.stub(:find)
      model.stub(:quoted_table_name)
      model.stub(:primary_key).and_return('pk')
    end

    describe "initialization" do
      it "complains if the model hasn't included Inheritance" do
        lambda { Inheritable.new(model) }.should raise_error(InvalidInheritage)
      end
    end

    describe "with Restriction-aware classes" do

      let(:inheritable)       { Inheritable.new(model) }
      let(:a_record)          { mock('a record',       :pk => 'an id') }
      let(:another_record)    { mock('another record', :pk => 'another id') }
      let(:some_other_record) { mock('some other record',
                                     :pk => 'some other id') }

      before do
        model.send(:include, Inheritance)
        model.stub(:parent_models_and_options).
          and_return([[reflected_model, :parent, 'find options']])
      end

      describe "#ids_with" do

        let(:results)         { [a_record, another_record, some_other_record] }
        let(:find_conditions) { stub('conditions') }
        let(:find_options)    { {:conditions => find_conditions} }
        let(:restricter)      { mock('restricter', :options => find_options) }

        before do
          model.stub(:unrestricted_find).and_return(results)
          model.stub(:parent_models_and_options).
            and_return([[reflected_model, :parent, 'filter']])
          Restricter.stub(:new).and_return(restricter)
        end

        it "gets the parent models and associations" do
          model.should_receive(:parent_models_and_options).
            and_return([[reflected_model, :parent, 'filter']])
          inheritable.ids_with('permissions inherited')
        end

        describe "for each reflected model" do

          it "builds a restricter for the reflected model" do
            Restricter.should_receive(:new).with(reflected_model).
              and_return(restricter)
            inheritable.ids_with('permissions inherited')
          end

          it "gets its options with the permissions and ids provided" do
            restricter.should_receive(:options).
              with('permissions inherited', 'filter').
              and_return(find_options)
            inheritable.ids_with('permissions inherited')
          end

          it "gets model ids joining reflected model and filtering ids" do
            # This uses .unrestricted_find to avoid infinite recursion.
            model.should_receive(:unrestricted_find).
              with(:all, :joins => :parent, :conditions => find_conditions).
              and_return(results)
            inheritable.ids_with('permissions inherited')
          end

        end

        describe "with all ids returned from partial findings" do

          let(:find_conditions1) { stub('conditions') }
          let(:find_options1)    { {:conditions => find_conditions1} }

          let(:find_conditions2) { stub('conditions') }
          let(:find_options2)    { {:conditions => find_conditions2} }

          it "accumulates them and returns it" do
            restricter.stub(:options).with('permissions inherited',
                                           'filter1').and_return(find_options1)
            restricter.stub(:options).with('permissions inherited',
                                           'filter2').and_return(find_options2)
            model.stub(:parent_models_and_options).and_return([
              [reflected_model, :parent1, 'filter1'],
              [reflected_model, :parent2, 'filter2']
            ])
            model.stub(:unrestricted_find).
              with(:all, :joins => :parent1, :conditions => find_conditions1).
              and_return([a_record, another_record])
            model.stub(:unrestricted_find).
              with(:all, :joins => :parent2, :conditions => find_conditions2).
              and_return([another_record, some_other_record])
            inheritable.ids_with('permissions inherited').should == \
              Set.new(['an id', 'another id', 'some other id'])
          end

        end

      end

    end
  end
end
