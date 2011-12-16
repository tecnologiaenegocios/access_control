require 'spec_helper'
require 'access_control/restricter'
require 'access_control/restriction'

module AccessControl
  describe Restricter do

    # A Restricter assembles a sql condition which can be used to filter ids in
    # a query based on permissions.

    let(:orm_class)   { Class.new }
    let(:restricter)  { Restricter.new(orm_class) }
    let(:inheritable) { stub('inheritable') }
    let(:blockable)   { stub('blockable') }
    let(:grantable)   { stub('grantable') }
    let(:manager)     { stub('manager') }
    let(:global_node) { stub('global node') }

    before do
      orm_class.stub(:full_pk).and_return('`table_name`.pk')
      orm_class.stub(:quote_values).and_return('quoted values')
      Grantable.stub(:new).with(orm_class).and_return(grantable)
      Blockable.stub(:new).with(orm_class).and_return(blockable)
      Inheritable.stub(:new).with(orm_class).and_return(inheritable)
      AccessControl.stub(:manager).and_return(manager)
      AccessControl.stub(:global_node).and_return(global_node)

      inheritable.stub(:ids_with).with('some permissions').
        and_return(Set.new([1,2,    5,6,    9]))
      blockable.stub(:ids).
        and_return(Set.new([      4,5,6      ]))
      grantable.stub(:ids_with).with('some permissions').
        and_return(Set.new([  2,  4,  6,  8  ]))
    end

    describe "#permitted_ids" do

      def get_ids(filter=nil)
        restricter.permitted_ids('some permissions', filter)
      end

      context "when there's no filter" do
        it "returns only valid ids" do
          # We should get all inheritable ids minus those that are blocked,
          # united with all grantable ids.
          valid_ids = (
            inheritable.ids_with('some permissions') - blockable.ids
          ) | grantable.ids_with('some permissions')
          get_ids.should == valid_ids
        end
        it "returns a set" do
          get_ids.should be_a(Set)
        end
      end

      context "when there's a filter" do
        it "returns valid ids intersected with those in the filter" do
          valid_ids = (
            inheritable.ids_with('some permissions') - blockable.ids
          ) | grantable.ids_with('some permissions')
          filter = Set.new([10, valid_ids.first])
          valid_ids = filter & valid_ids # This should let only one id.
          get_ids(filter).should == valid_ids
        end
        it "returns a set" do
          filter = Set.new
          get_ids(filter).should be_a(Set)
        end
      end

    end

    describe "#sql_condition" do

      # Returns a sql condition for scoping a primary key with a :conditions
      # option.

      let(:some_permissions) { 'some permissions' }

      def restricter_condition(filter='some filtering ids')
        restricter.sql_condition(some_permissions, filter)
      end

      before do
        manager.stub(:can?).with(some_permissions, global_node).and_return(false)
        grantable.stub(:from_class?).and_return(false)
      end

      context "when the global node grants the permission" do
        before do
          manager.stub(:can?).with(some_permissions, global_node).
            and_return(true)
        end

        it "adds no restriction if the global node grants the permission" do
          restricter_condition.should == '1'
        end
      end

      context "when the class doesn't grant the permission" do

        let(:permitted_ids) { Set.new(['permitted ids']) }

        before do
          grantable.stub(:from_class?).and_return(false)
          restricter.stub(:permitted_ids).
            with(some_permissions, 'some filtering ids').
            and_return(permitted_ids)
        end

        specify "if no filter is passed, nil is passed to #permitted_ids" do
          restricter.should_receive(:permitted_ids).
            with(some_permissions, nil).and_return(permitted_ids)
          restricter.sql_condition(some_permissions)
        end

        context "when there are ids left to narrow down the outer query" do
          let(:quoted_values) { 'quoted values' }
          before do
            orm_class.stub(:quote_values).with(['permitted ids']).
              and_return(quoted_values)
          end
          it "builds a condition expression for the primary key" do
            restricter_condition.should == "`table_name`.pk IN (quoted values)"
          end
        end

        context "when there are no ids left" do
          before { restricter.stub(:permitted_ids).and_return(Set.new) }
          it "returns a condition that is always false" do
            restricter_condition.should == '0'
          end
        end
      end

      context "when the class grants the permission" do

        before do
          grantable.stub(:from_class?).and_return(true)
          orm_class.stub(:quote_values) do |values|
            quote(values)
          end
        end

        def quote values
          values.map(&:to_s).join(',')
        end

        describe "when there are blocked ids" do

          it "builds a condition expression for the primary key" do
            # We should get all blocked nodes minus those that are explicitly
            # granted in a NOT IN expression.
            invalid_ids = blockable.ids - grantable.ids_with('some permissions')
            restricter_condition.should ==
              "`table_name`.pk NOT IN (#{quote(invalid_ids)})"
          end

          it "ignores the filter" do
            invalid_ids = blockable.ids - grantable.ids_with('some permissions')
            restricter_condition(['whatever']).should ==
              "`table_name`.pk NOT IN (#{quote(invalid_ids)})"
          end

          describe "when all blocked ids are granted" do

            before do
              grantable.stub(:ids_with).and_return(blockable.ids)
            end

            it "virtually adds no restriction" do
              restricter_condition.should == '1'
            end
          end
        end

        describe "when there's no blocked id" do
          before { blockable.stub(:ids).and_return(Set.new) }

          describe "when a filter is provided" do
            it "builds a condition using only the filter" do
              restricter_condition([1, 2, 3]).should ==
                "`table_name`.pk IN (#{quote([1, 2, 3])})"
            end
          end

          describe "when a filter is not provided" do
            it "virtually adds no restriction" do
              restricter_condition(nil).should == '1'
            end
          end
        end

      end

    end
  end
end
