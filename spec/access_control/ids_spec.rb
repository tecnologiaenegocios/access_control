require 'spec_helper'
require 'access_control/ids'

module AccessControl
  describe Ids do
    let(:connection) { mock('connection') }
    let(:scoped)     { mock('scoped') }
    let(:model)      { mock('model', :connection => connection) }

    before do
      model.stub(:scoped).and_return(scoped)
      model.stub(:quoted_table_name).and_return('the_table_name')
      model.extend(Ids)
    end

    describe ".ids" do
      before do
        connection.stub(:select_values).and_return(['some id'])
        scoped.stub(:to_sql).and_return('the resulting sql')
      end

      def call_method
        model.ids
      end

      it "gets the scoped model with a select involving only the id" do
        model.should_receive(:scoped).with(
          :select => "#{model.quoted_table_name}.id"
        ).and_return(scoped)
        call_method
      end

      it "gets the sql from the scoped" do
        scoped.should_receive(:to_sql).and_return('the resulting sql')
        call_method
      end

      it "does a select for only the id column using the driver" do
        connection.should_receive(:select_values).
          with('the resulting sql').and_return([])
        call_method
      end

      it "returns the array returned by the driver" do
        call_method.should == ['some id']
      end
    end

    describe ".with_ids" do
      it "issues an anonymous scope querying by ids" do
        model.should_receive(:scoped).
          with(:conditions => { :id => 'the ids' })
        model.with_ids('the ids')
      end

      it "returns the resulting scope" do
        model.with_ids('the ids').should == scoped
      end
    end

    describe ".<belongs_to_association>_ids" do

      let(:result)      { stub(:the_parent_id_key_name => 'some id') }
      let(:reflections) { {} }

      before do
        model.stub(:reflections).and_return(reflections)
        model.stub(:all).and_return([result])
        reflections[:parent] = stub(
          :belongs_to? => true,
          :primary_key_name => 'the_parent_id_key_name'
        )
        reflections[:other] = stub(:belongs_to? => false)
      end

      context "calling a method with the right pattern" do

        context "corresponding to a belongs_to association" do

          before do
            connection.stub(:select_values).and_return(['some id'])
            scoped.stub(:to_sql).and_return('the resulting sql')
          end

          def call_method
            model.parent_ids
          end

          it "gets the scoped model with a select involving only the "\
             "association key" do
            model.should_receive(:scoped).with(
              :select => "#{model.quoted_table_name}.the_parent_id_key_name"
            ).and_return(scoped)
            call_method
          end

          it "gets the sql from the scoped" do
            scoped.should_receive(:to_sql).and_return('the resulting sql')
            call_method
          end

          it "does a select for only the association key using the driver" do
            connection.should_receive(:select_values).
              with('the resulting sql').and_return([])
            call_method
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
