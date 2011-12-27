require 'spec_helper'
require 'access_control/ids'

module AccessControl
  describe Ids do
    let(:connection) { mock('connection') }
    let(:scoped)     { mock('scoped') }
    let(:model)      { mock('model', :connection => connection) }

    before do
      model.stub(:quoted_table_name).and_return('the_table_name')
      model.stub(:scoped).
        with(:select => "DISTINCT #{model.quoted_table_name}.column").
        and_return(scoped)
      scoped.stub(:sql).and_return('the resulting sql')
      model.extend(Ids)
    end

    describe ".select_values_of_column" do
      before do
        connection.stub(:select_values).
          with('the resulting sql').
          and_return(['some value'])
        scoped.stub(:sql).and_return('the resulting sql')
      end

      def call_method
        model.select_values_of_column(:column)
      end

      it "returns the array returned by the driver" do
        call_method.should == ['some value']
      end
    end

    describe ".ids" do
      def call_method
        model.ids
      end

      it "forwards the call to select_values_of_column using :id" do
        model.stub(:select_values_of_column).
          with(:id).and_return('whatever is returned')
        call_method.should == 'whatever is returned'
      end
    end

    describe ".with_ids" do
      it "issues an anonymous scope querying by ids" do
        model.stub(:scoped).
          with(:conditions => { :id => 'the ids' }).
          and_return('the records with the ids')
        model.with_ids('the ids').should == 'the records with the ids'
      end
    end

    describe ".<belongs_to_association>_ids" do

      let(:result)      { stub(:the_parent_id_key_name => 'some id') }
      let(:reflections) { {} }

      before do
        model.stub(:reflections).and_return(reflections)
        model.stub(:all).and_return([result])
        model.stub(:scoped).with(
          :select => "DISTINCT #{model.quoted_table_name}.the_parent_id_key_name"
        ).and_return(scoped)
        reflections[:parent] = stub(
          :belongs_to? => true,
          :primary_key_name => 'the_parent_id_key_name'
        )
        reflections[:other] = stub(:belongs_to? => false)
      end

      context "calling a method with the right pattern" do

        context "corresponding to a belongs_to association" do

          before do
            connection.stub(:select_values).
              with('the resulting sql').
              and_return(['some id'])
            scoped.stub(:sql).and_return('the resulting sql')
          end

          def call_method
            model.parent_ids
          end

          it "return the array returned by the driver" do
            call_method.should == ['some id']
          end
        end

        context "not corresponding to a belongs_to association" do
          it "chains to superclass' method_missing" do
            lambda {
              model.other_ids
            }.should raise_exception(Spec::Mocks::MockExpectationError)
          end
        end

        context "not corresponding to any reflection" do
          it "chains to superclass' method_missing" do
            lambda {
              model.something_not_reflection_ids
            }.should raise_exception(Spec::Mocks::MockExpectationError)
          end
        end

      end

      context "calling any other undefined method" do
        it "chains to superclass' method_missing" do
          lambda {
            model.any_other_undefined_method
          }.should raise_exception(Spec::Mocks::MockExpectationError)
        end
      end

    end

  end
end
