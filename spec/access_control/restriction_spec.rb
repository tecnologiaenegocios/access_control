require 'spec_helper'
require 'access_control/exceptions'
require 'access_control/restriction'

module AccessControl
  describe Restriction do

    let(:base) { ActiveRecord::Base }
    let(:model) { Class.new(base) }

    before do
      model.send(:include, Restriction)
    end

    describe ".with_permissions" do

      let(:manager) { mock('manager') }

      before do
        manager.stub(:principal_ids).and_return(['id'])
        AccessControl.stub(:security_manager).and_return(manager)
      end

      it "left joins access control tables" do
        # This is annoying to spec, so we just check if the SQL returned has
        # the joins, but not check the conditions.

        options = model.with_permissions.proxy_options

        # Left joins ac_node (and not inner joins it) for performance reasons.
        options[:joins].should =~ /LEFT JOIN `ac_nodes`/

        # All the others are left (and not inner) joined because the node may
        # not have any assignment.
        options[:joins].should =~ /LEFT JOIN `ac_assignments`/
        options[:joins].should =~ /LEFT JOIN `ac_roles`/
        options[:joins].should =~ /LEFT JOIN `ac_security_policy_items`/
      end

      it "gets the principal ids when called" do
        manager.should_receive(:principal_ids).and_return(['id', 'another id'])
        model.with_permissions
      end

      describe "with a single principal" do

        before do
          manager.stub(:principal_ids).and_return(['id'])
        end

        it "extracts the single principal and put it on the conditions" do
          model.with_permissions.proxy_options[:conditions].should == {
            :'ac_security_policy_items.principal_id' => 'id'
          }
        end

      end

      describe "with more than one principal" do

        before do
          manager.stub(:principal_ids).and_return(['id', 'another id'])
        end

        it "copies the entire array of principal ids in conditions" do
          model.with_permissions.proxy_options[:conditions].should == {
            :'ac_security_policy_items.principal_id' => ['id', 'another id']
          }
        end

      end
    end

    describe ".with_unblocked_nodes" do
      it "restricts nodes to only unblocked ones" do
        scope = model.with_unblocked_nodes
        scope.proxy_options[:conditions].should == { :'ac_nodes.block' => 0 }
      end
    end

    describe ".granted" do

      let(:restricter) { mock('restricter') }

      before do
        restricter.stub(:options).and_return({})
        Restricter.stub(:new).and_return(restricter)
      end

      it "creates a restricter instance from the model class" do
        Restricter.should_receive(:new).with(model).and_return(restricter)
        model.granted('some permissions')
      end

      it "gets the options from the restricter" do
        restricter.should_receive(:options).with('some permissions').
          and_return({})
        model.granted('some permissions')
      end

      it "uses the options from the restricter" do
        restricter.stub(:options).and_return({:value => 'value'})
        scope = model.granted('some permissions')
        scope.proxy_options.should == {:value => 'value'}
      end

    end

    describe ".find" do

      let(:proxy) { mock('proxy', :find_without_permissions => nil) }
      before { model.stub(:with_permissions).and_return(proxy) }

      it "always calls the .with_permissions named scope" do
        model.should_receive(:with_permissions).and_return(proxy)
        model.find
      end

      it "forwards all parameters to proxy's find" do
        proxy.should_receive(:find_without_permissions).with('find arguments')
        model.find('find arguments')
      end

      it "returns the result of calling proxy's find" do
        proxy.stub(:find_without_permissions).and_return('found results')
        model.find.should == 'found results'
      end

    end

  end

  describe Restricter do

    let(:base) { ActiveRecord::Base }
    let(:model) { Class.new(base) }

    describe "initialization" do
      it "complains if the model hasn't included Restriction" do
        lambda { Restricter.new(model) }.should raise_error(CannotRestrict)
      end
    end

    describe "with Restriction-aware classes" do

      let(:restricter) { Restricter.new(model) }

      before do
        model.include(Restriction)
      end

    end

  end
end
