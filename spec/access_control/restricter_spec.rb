require 'spec_helper'
require 'access_control/restricter'
require 'access_control/restriction'

module AccessControl
  describe Restricter do

    # A Restricter assembles a sql condition which can be used to filter ids in
    # a query based on permissions.

    let(:model) { Class.new }
    let(:restricter) { Restricter.new(model) }

    before do
      model.stub(:named_scope)
      model.stub(:find)
      model.stub(:quoted_table_name).and_return('`table_name`')
      model.stub(:primary_key).and_return('pk')
      model.send(:include, Restriction)
    end

    describe "#sql_condition" do

      # Returns a sql condition for scoping a primary key with a :conditions
      # option.

      let(:inheritable) { mock(:ids_with => Set.new([1,2,    5,6,    9])) }
      let(:blockable)   { mock(:ids      => Set.new([      4,5,6      ])) }
      let(:grantable)   { mock(:ids_with => Set.new([  2,  4,  6,  8  ])) }

      def restricter_condition(filter=nil)
        restricter.sql_condition('some permissions', filter)
      end

      before do
        Grantable.stub(:new).and_return(grantable)
        Blockable.stub(:new).and_return(blockable)
        Inheritable.stub(:new).and_return(inheritable)
      end

      describe "when the class doesn't grant the permission" do

        before do
          grantable.stub(:from_class?).and_return(false)
        end

        it "creates a inheritable from the model" do
          Inheritable.should_receive(:new).with(model).and_return(inheritable)
          restricter_condition
        end

        it "creates a grantable from the model" do
          Grantable.should_receive(:new).with(model).and_return(grantable)
          restricter_condition
        end

        it "creates a blockable from the model" do
          Blockable.should_receive(:new).with(model).and_return(blockable)
          restricter_condition
        end

        it "asks the grantable if the class grants the permissions" do
          grantable.should_receive(:from_class?).and_return(false)
          restricter_condition
        end

        it "gets inherited ids" do
          ids = inheritable.ids_with
          inheritable.should_receive(:ids_with).with('some permissions').
            and_return(ids)
          restricter_condition
        end

        it "gets granted ids" do
          ids = grantable.ids_with
          grantable.should_receive(:ids_with).with('some permissions').
            and_return(ids)
          restricter_condition
        end

        it "gets blocked ids" do
          ids = blockable.ids
          blockable.should_receive(:ids).and_return(ids)
          restricter_condition
        end

        context "when there are ids left to narrow down the outer query" do
          it "builds a condition expression for the primary key" do
            # We should get all inheritable ids minus those that are blocked,
            # united with all grantable ids.
            valid_ids = (inheritable.ids_with - blockable.ids) |
              grantable.ids_with
            restricter_condition.should ==
              ["`table_name`.pk IN (?)", valid_ids.to_a]
          end

          it "filters out ids not in the filter" do
            valid_ids = (inheritable.ids_with - blockable.ids) |
              grantable.ids_with
            filter = Set.new([10, valid_ids.first])
            valid_ids = filter & valid_ids # This should let only one id.
            restricter_condition(filter.to_a).should ==
              ["`table_name`.pk IN (?)", valid_ids.to_a]
          end
        end

        context "when there are no ids left" do
          it "returns a condition that is always false" do
            # The '0' can be used for other components to avoid a known-empty
            # query.
            inheritable.stub(:ids_with).and_return(Set.new)
            grantable.stub(:ids_with).and_return(Set.new)
            restricter_condition.should == '0'
          end
        end

      end

      describe "when the class grants the permission" do

        before do
          grantable.stub(:from_class?).and_return(true)
        end

        it "creates a grantable from the model" do
          Grantable.should_receive(:new).with(model).and_return(grantable)
          restricter_condition
        end

        it "creates a blockable from the model" do
          Blockable.should_receive(:new).with(model).and_return(blockable)
          restricter_condition
        end

        it "asks the grantable if the class grants the permissions" do
          grantable.should_receive(:from_class?).and_return(true)
          restricter_condition
        end

        it "gets granted ids" do
          ids = grantable.ids_with
          grantable.should_receive(:ids_with).with('some permissions').
            and_return(ids)
          restricter_condition
        end

        it "gets blocked ids" do
          ids = blockable.ids
          blockable.should_receive(:ids).and_return(ids)
          restricter_condition
        end

        describe "when there are blocked ids" do

          it "builds a condition expression for the primary key" do
            # We should get all blocked nodes minus those that are explicitly
            # granted in a NOT IN expression.
            invalid_ids = blockable.ids - grantable.ids_with
            restricter_condition.should ==
              ["`table_name`.pk NOT IN (?)", invalid_ids.to_a]
          end

          it "ignores the filter" do
            invalid_ids = blockable.ids - grantable.ids_with
            restricter_condition(['whatever']).should ==
              ["`table_name`.pk NOT IN (?)", invalid_ids.to_a]
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
                ["`table_name`.pk IN (?)", [1, 2, 3]]
            end
          end

          describe "when a filter is not provided" do
            it "virtually adds no restriction" do
              restricter_condition.should == '1'
            end
          end
        end

      end

    end
  end
end
