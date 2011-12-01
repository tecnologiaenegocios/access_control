require 'spec_helper'
require 'access_control/behavior'
require 'access_control/security_policy_item'

module AccessControl
  describe SecurityPolicyItem do

    describe ".role_ids" do
      it "maps to #role_id for each existing item" do
        r = SecurityPolicyItem.new(:role_id => 12345, :permission => 'foo')
        r.save(false)
        SecurityPolicyItem.role_ids.should == [12345]
      end
    end

    describe ".with_permission" do
      let(:item1) do
        SecurityPolicyItem.create!(:role_id => 0, :permission => 'permission 1')
      end
      let(:item2) do
        SecurityPolicyItem.create!(:role_id => 0, :permission => 'permission 2')
      end
      before { item1; item2 }
      it "returns items for the specified permission" do
        SecurityPolicyItem.with_permission('permission 1').should include(item1)
      end
      it "rejects items for not specified permissions" do
        SecurityPolicyItem.with_permission('permission 1').
          should_not include(item2)
      end
      it "accepts an array" do
        collection = SecurityPolicyItem.
          with_permission(['permission 1', 'permission 2'])
        collection.should include(item1)
        collection.should include(item2)
      end
    end

    describe "mass-update/create/destroy items" do

      let(:item1) do
        SecurityPolicyItem.create!(:role_id => 0,
                                   :permission => 'a permission')
      end
      let(:item2) do
        SecurityPolicyItem.create!(:role_id => 0,
                                   :permission => 'another permission')
      end
      let(:item3) do
        SecurityPolicyItem.create!(:role_id => 1,
                                   :permission => 'a permission')
      end
      let(:item4) do
        SecurityPolicyItem.create!(:role_id => 2,
                                   :permission => 'a permission')
      end
      let(:item5) do
        SecurityPolicyItem.create!(:role_id => 2,
                                   :permission => 'another permission')
      end

      it "can mass-update or mass-destroy with a hash of attribute hashes" do
        SecurityPolicyItem.mass_manage!({
          '0' => {:id => item1.to_param, :role_id => '3', :_destroy => '0'},
          '1' => {:id => item2.to_param, :role_id => '3'},
          '2' => {:id => item3.to_param,
                  :permission => 'some other permission'},
          '3' => {:id => item4.to_param, :_destroy => '1'},
          '4' => {:id => item5.to_param, :_destroy => '1'},
          '5' => {:role_id => '1', :id => '',
                  :permission => 'another permission'},
          '6' => {:role_id => '2',
                  :permission => 'some other permission'}
        })
        SecurityPolicyItem.find(item1.id).role_id.should == 3
        SecurityPolicyItem.find(item1.id).permission.should == 'a permission'
        SecurityPolicyItem.find(item2.id).role_id.should == 3
        SecurityPolicyItem.find(item2.id).
          permission.should == 'another permission'
        SecurityPolicyItem.find(item3.id).role_id.should == 1
        SecurityPolicyItem.find(item3.id).
          permission.should == 'some other permission'
        SecurityPolicyItem.find_by_id(item4.id).should be_nil
        SecurityPolicyItem.find_by_id(item5.id).should be_nil
        SecurityPolicyItem.find_by_role_id_and_permission(
          1, 'another permission'
        ).should_not be_nil
        SecurityPolicyItem.find_by_role_id_and_permission(
          2, 'some other permission'
        ).should_not be_nil
      end

      it "can mass-update or mass-destroy with an array of attribute hashes" do
        SecurityPolicyItem.mass_manage!([
          {:id => item1.to_param, :role_id => '3', :_destroy => '0'},
          {:id => item2.to_param, :role_id => '3'},
          {:id => item3.to_param, :permission => 'some other permission'},
          {:id => item4.to_param, :_destroy => '1'},
          {:id => item5.to_param, :_destroy => '1'},
          {:role_id => '1', :id => '',
           :permission => 'another permission'},
          {:role_id => '2', :permission => 'some other permission'}
        ])
        SecurityPolicyItem.find(item1.id).role_id.should == 3
        SecurityPolicyItem.find(item1.id).permission.should == 'a permission'
        SecurityPolicyItem.find(item2.id).role_id.should == 3
        SecurityPolicyItem.find(item2.id).
          permission.should == 'another permission'
        SecurityPolicyItem.find(item3.id).role_id.should == 1
        SecurityPolicyItem.find(item3.id).
          permission.should == 'some other permission'
        SecurityPolicyItem.find_by_id(item4.id).should be_nil
        SecurityPolicyItem.find_by_id(item5.id).should be_nil
        SecurityPolicyItem.find_by_role_id_and_permission(
          1, 'another permission'
        ).should_not be_nil
        SecurityPolicyItem.find_by_role_id_and_permission(
          2, 'some other permission'
        ).should_not be_nil
      end

      it "raises ActiveRecord::RecordNotFound if some item is not found" do
        lambda {
          SecurityPolicyItem.mass_manage!([
            {:id => -10, :role_id => '3', :_destroy => '0'}
          ])
        }.should raise_exception(ActiveRecord::RecordNotFound)
      end

      it "raises ActiveRecord:RecordInvalid if some item is not valid" do
        SecurityPolicyItem.stub!(:find).and_return(item1)
        item1.stub!(:valid?).and_return(false)
        lambda {
          SecurityPolicyItem.mass_manage!([
            {:id => item1.to_param, :role_id => '3'}
          ])
        }.should raise_exception(ActiveRecord::RecordInvalid)
      end

      it "clears the global node cache" do
        SecurityPolicyItem.stub(:find).and_return(item1)
        AccessControl.should_receive(:clear_global_node_cache).once
        SecurityPolicyItem.mass_manage!([
          {:id => item1.to_param, :role_id => '3'}
        ])
      end

    end

    describe "items for management" do

      before do
        roles = [
          @role1 = Role.create!(:name => 'role1'),
          @role2 = Role.create!(:name => 'role2')
        ]
        @item = SecurityPolicyItem.create!(:role => @role1,
                                           :permission => 'a permission')
        Registry.stub!(:all).and_return(Set.new([
          'another permission', 'some other permission'
        ]))
        @items = SecurityPolicyItem.items_for_management(roles)
      end

      it "returns one key for each different permission" do
        @items.size.should == 3
      end

      it "returns one value for each role passed" do
        @items['a permission'].size.should == 2
        @items['another permission'].size.should == 2
        @items['some other permission'].size.should == 2
      end

      it "returns the item that exists" do
        @items['a permission'].first.should == @item
      end

      it "returns a new item if there's no security policy items" do
        @items['a permission'].second.should be_new_record
        @items['a permission'].second.role_id.should == @role2.id
        @items['a permission'].second.permission.should == 'a permission'

        @items['another permission'].first.should be_new_record
        @items['another permission'].first.role_id.should == @role1.id
        @items['another permission'].first.permission.
          should == 'another permission'
        @items['another permission'].second.should be_new_record
        @items['another permission'].second.role_id.should == @role2.id
        @items['another permission'].second.permission.
          should == 'another permission'

        @items['some other permission'].first.should be_new_record
        @items['some other permission'].first.role_id.should == @role1.id
        @items['some other permission'].first.permission.
          should == 'some other permission'
        @items['some other permission'].second.should be_new_record
        @items['some other permission'].second.role_id.should == @role2.id
        @items['some other permission'].second.permission.
          should == 'some other permission'
      end
    end

  end
end
