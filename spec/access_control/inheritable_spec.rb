require 'spec_helper'
require 'access_control/inheritable'
require 'access_control/inheritance'
require 'access_control/restriction'

module AccessControl
  describe Inheritable do

    # An Inheritable object takes a ORM class and a set of permissions and gets
    # the primary key values of the ORM class's table to which those
    # permissions are propagated from parent ORM classes.

    let(:orm_adapted) { Class.new }
    let(:orm_class) { stub('ORM class', :object => orm_adapted) }
    let(:reflected_orm_class) { stub('another ORM class') }

    before do
      orm_class.stub(:full_pk).and_return('`table_name`.pk')
    end

    describe "initialization" do
      it "complains if the orm class hasn't included Inheritance" do
        # Inheritance is needed for .parent_models_and_options.
        lambda { Inheritable.new(orm_class) }.
          should raise_error(InvalidInheritage)
      end
    end

    describe "with Inheritance-aware classes" do

      let(:inheritable)       { Inheritable.new(orm_class) }

      before do
        orm_adapted.send(:include, Inheritance)
        orm_adapted.stub(:inherits_permissions_from).
          and_return([:parent1, :parent2])
      end

      describe "#ids_with" do

        let(:parent1_pks)            { [1] }
        let(:parent2_pks)            { [2] }
        let(:inherited_from_parent1) { [1, 2, 3] }
        let(:inherited_from_parent2) { [2, 3, 4] }
        let(:sql_condition1)         { 'sql condition 1' }
        let(:sql_condition2)         { 'sql condition 2' }
        let(:restricter)             { mock('restricter') }

        before do
          orm_class.stub(:associated_class).and_return(reflected_orm_class)
          orm_class.stub(:foreign_keys).with(:parent1).and_return(parent1_pks)
          orm_class.stub(:foreign_keys).with(:parent2).and_return(parent2_pks)
          Restricter.stub(:new).and_return(restricter)
          restricter.stub(:sql_condition).
            with('permissions inherited', parent1_pks).
            and_return(sql_condition1)
          restricter.stub(:sql_condition).
            with('permissions inherited', parent2_pks).
            and_return(sql_condition2)

          orm_class.stub(:primary_keys).with(sql_condition1, :parent1).
            and_return(inherited_from_parent1)
          orm_class.stub(:primary_keys).with(sql_condition2, :parent2).
            and_return(inherited_from_parent2)
        end

        describe "for each reflected orm class" do

          it "gets each of the associated classes" do
            orm_class.should_receive(:associated_class).with(:parent1).
              and_return(reflected_orm_class)
            orm_class.should_receive(:associated_class).with(:parent2).
              and_return(reflected_orm_class)
            inheritable.ids_with('permissions inherited')
          end

          it "gets each of the foreign keys for each association" do
            orm_class.should_receive(:foreign_keys).with(:parent1).
              and_return(parent1_pks)
            orm_class.should_receive(:foreign_keys).with(:parent2).
              and_return(parent2_pks)
            inheritable.ids_with('permissions inherited')
          end

          it "builds a restricter with the reflected orm class" do
            Restricter.should_receive(:new).twice.
              with(reflected_orm_class).
              and_return(restricter)
            inheritable.ids_with('permissions inherited')
          end

          it "gets a condition for each parent association" do
            restricter.should_receive(:sql_condition).
              with('permissions inherited', parent1_pks).
              and_return(sql_condition1)
            restricter.should_receive(:sql_condition).
              with('permissions inherited', parent2_pks).
              and_return(sql_condition2)
            inheritable.ids_with('permissions inherited')
          end

          context "when a non-falsy condition is returned" do
            it "gets orm class ids" do
              orm_class.should_receive(:primary_keys).
                with(sql_condition1, :parent1).
                and_return(inherited_from_parent1)
              orm_class.should_receive(:primary_keys).
                with(sql_condition2, :parent2).
                and_return(inherited_from_parent2)
              inheritable.ids_with('permissions inherited')
            end

            it "returns the union of the ids" do
              inheritable.ids_with('permissions inherited').should == Set.new(
                [1, 2, 3, 4]
              )
            end
          end

          context "when a falsy condition is returned" do
            before do
              restricter.stub(:sql_condition).
                with('permissions inherited', parent1_pks).
                and_return('0')
            end

            it "skips quering the orm class ids" do
              orm_class.should_not_receive(:primary_keys).with(sql_condition1)
              inheritable.ids_with('permissions inherited')
            end

            it "doesn't join that ids in the final result" do
              inheritable.ids_with('permissions inherited').should == Set.new(
                [2, 3, 4]
              )
            end
          end
        end

      end

    end
  end
end
