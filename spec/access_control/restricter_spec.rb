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

      let(:inheritable) { mock(:ids_with => Set.new([1,2,3,  5,6,7    ])) }
      let(:blockable)   { mock(:ids      => Set.new([      4,5,6      ])) }
      let(:grantable)   { mock(:ids_with => Set.new([  2,  4,  6,  8,9])) }

      def restricter_options(filter=nil)
        restricter.options('some permissions', filter)
      end

      before do
        Grantable.stub(:new).and_return(grantable)
        Blockable.stub(:new).and_return(blockable)
        Inheritable.stub(:new).and_return(inheritable)
      end

      it "creates a inheritable out from the model" do
        Inheritable.should_receive(:new).and_return(inheritable)
        restricter_options
      end

      it "creates a grantable out from the model" do
        Grantable.should_receive(:new).and_return(grantable)
        restricter_options
      end

      it "creates a blockable out from the model" do
        Blockable.should_receive(:new).and_return(blockable)
        restricter_options
      end

      it "gets inheritable ids" do
        ids = inheritable.ids_with
        inheritable.should_receive(:ids_with).with('some permissions').
          and_return(ids)
        restricter_options
      end

      it "gets grantable ids without a filter if none is provided" do
        ids = grantable.ids_with
        grantable.should_receive(:ids_with).with('some permissions', nil).
          and_return(ids)
        restricter_options
      end

      it "gets grantable ids with the filter if one is provided" do
        filter = stub('filter')
        ids = grantable.ids_with
        grantable.should_receive(:ids_with).with('some permissions', filter).
          and_return(ids)
        restricter_options(filter)
      end

      it "gets blocked ids" do
        ids = blockable.ids
        blockable.should_receive(:ids).and_return(ids)
        restricter_options
      end

      it "builds a condition expression for the primary key" do
        # We should get all inheritable ids minus those that are blocked,
        # united with all grantable ids.
        valid_ids = (inheritable.ids_with - blockable.ids) | grantable.ids_with
        restricter_options[:conditions].should == ["`table_name`.pk IN (?)",
                                                   valid_ids.to_a]
      end

    end
  end
end
