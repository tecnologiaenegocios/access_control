require 'spec_helper'
require 'access_control/restricter'
require 'access_control/restriction'

module AccessControl
  describe Restricter do

    # A Restricter assembles a :conditions option which can be used in named
    # scopes based on a set of permissions.

    let(:model) { Class.new }
    let(:restricter) { Restricter.new(model) }

    before do
      model.stub(:named_scope)
      model.stub(:find)
      model.stub(:quoted_table_name).and_return('`table_name`')
      model.stub(:primary_key).and_return('pk')
      model.send(:include, Restriction)
    end

    describe "#options" do

      # Returns an options hash for scoping with a :conditions option.

      let(:inheritable) { mock(:ids_with => Set.new([1,2,    5,6,    9])) }
      let(:blockable)   { mock(:ids      => Set.new([      4,5,6      ])) }
      let(:grantable)   { mock(:ids_with => Set.new([  2,  4,  6,  8  ])) }

      def restricter_options(filter=nil)
        restricter.options('some permissions', filter)
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
          restricter_options
        end

        it "creates a grantable from the model" do
          Grantable.should_receive(:new).with(model).and_return(grantable)
          restricter_options
        end

        it "creates a blockable from the model" do
          Blockable.should_receive(:new).with(model).and_return(blockable)
          restricter_options
        end

        it "asks the grantable if the class grants the permissions" do
          grantable.should_receive(:from_class?).and_return(false)
          restricter_options
        end

        it "gets inherited ids" do
          ids = inheritable.ids_with
          inheritable.should_receive(:ids_with).with('some permissions').
            and_return(ids)
          restricter_options
        end

        it "gets granted ids" do
          ids = grantable.ids_with
          grantable.should_receive(:ids_with).with('some permissions').
            and_return(ids)
          restricter_options
        end

        it "gets blocked ids" do
          ids = blockable.ids
          blockable.should_receive(:ids).and_return(ids)
          restricter_options
        end

        it "builds a condition expression for the primary key" do
          # We should get all inheritable ids minus those that are blocked,
          # united with all grantable ids.
          valid_ids = (inheritable.ids_with - blockable.ids)|grantable.ids_with
          restricter_options[:conditions].should == ["`table_name`.pk IN (?)",
                                                     valid_ids.to_a]
        end

        it "filters out ids not in the filter" do
          valid_ids = (inheritable.ids_with - blockable.ids)|grantable.ids_with
          filter = Set.new([10, valid_ids.first])
          valid_ids = filter & valid_ids # This should let only one id.
          restricter_options(filter.to_a)[:conditions].should ==
            ["`table_name`.pk IN (?)", valid_ids.to_a]
        end

      end

      describe "when the class grants the permission" do

        before do
          grantable.stub(:from_class?).and_return(true)
        end

        it "creates a grantable from the model" do
          Grantable.should_receive(:new).with(model).and_return(grantable)
          restricter_options
        end

        it "creates a blockable from the model" do
          Blockable.should_receive(:new).with(model).and_return(blockable)
          restricter_options
        end

        it "asks the grantable if the class grants the permissions" do
          grantable.should_receive(:from_class?).and_return(true)
          restricter_options
        end

        it "gets granted ids" do
          ids = grantable.ids_with
          grantable.should_receive(:ids_with).with('some permissions').
            and_return(ids)
          restricter_options
        end

        it "gets blocked ids" do
          ids = blockable.ids
          blockable.should_receive(:ids).and_return(ids)
          restricter_options
        end

        describe "when there are blocked ids" do

          it "builds a condition expression for the primary key" do
            # We should get all blocked nodes minus those that are explicitly
            # granted in a NOT IN expression.
            invalid_ids = blockable.ids - grantable.ids_with
            restricter_options[:conditions].should ==
              ["`table_name`.pk NOT IN (?)", invalid_ids.to_a]
          end

          it "ignores the filter" do
            invalid_ids = blockable.ids - grantable.ids_with
            restricter_options(['whatever'])[:conditions].should ==
              ["`table_name`.pk NOT IN (?)", invalid_ids.to_a]
          end

        end

        describe "when there's no blocked id" do
          before { blockable.stub(:ids).and_return(Set.new) }

          describe "when a filter is provided" do
            it "builds a condition using only the filter" do
              restricter_options([1, 2, 3])[:conditions].should ==
                ["`table_name`.pk IN (?)", [1, 2, 3]]
            end
          end

          describe "when a filter is not provided" do
            it "virtually adds no restriction" do
              restricter_options.should == {}
            end
          end
        end

      end

    end
  end
end
