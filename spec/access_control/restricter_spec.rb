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

      let(:inheritable) { mock('inheritable', :ids_with => ['inheritable id']) }
      let(:grantable)   { mock('grantable',   :ids_with => ['granted id']) }
      let(:blockable)   { mock('blockable',   :ids => ['blocked id']) }

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
        inheritable.should_receive(:ids_with).with('some permissions').
          and_return(['inheritable id'])
        restricter_options
      end

      it "gets grantable ids without a filter if none is provided" do
        grantable.should_receive(:ids_with).with('some permissions', nil).
          and_return(['granted id'])
        restricter_options
      end

      it "gets grantable ids with the filter if one is provided" do
        filter = stub('filter')
        grantable.should_receive(:ids_with).with('some permissions', filter).
          and_return(['granted id'])
        restricter_options(filter)
      end

      it "gets blocked ids" do
        blockable.should_receive(:ids).and_return(['blocked id'])
        restricter_options
      end

      it "builds a condition expression for the primary key" do
        restricter_options[:conditions].should == [
          "`table_name`.pk IN (?) OR (`table_name`.pk IN (?) AND `table_name`.pk NOT IN (?))",
          ['granted id'], ['inheritable id'], ['blocked id']
        ]
      end

      describe "with empty blocked ids" do

        # The specific feature below is needed because of two things:
        # - NOT IN expressions with an empty set are bad, at least with the
        #   default behaviour in Rails and MySQL.  Those are turned into NOT
        #   IN (NULL) by Rails, which yields false always, no matter what is
        #   being tested for not being in the set.  But this should yield
        #   true in all cases because everything is not in an empty set.
        # - We end up without the OR expression (which can't use indices),
        #   and with just a simple IN expression, which is better for
        #   performance.  Stripping out the NOT IN condition, the resulting
        #   expression is an OR expression testing the same id in two sets.
        #   Then we can merge both sets into one and use a single IN
        #   expression, stripping out the OR.

        it "simplifies the condition to a single IN expression" do
          blockable.stub(:ids).and_return([])
          restricter_options[:conditions].should == [
            "`table_name`.pk IN (?)", ['granted id', 'inheritable id']
          ]
        end

      end
    end
  end
end
