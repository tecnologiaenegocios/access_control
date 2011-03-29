require 'spec_helper'

module AccessControl
  describe SecurityPolicyItem do

    it "cannot be wrapped by a security proxy" do
      SecurityPolicyItem.securable?.should be_false
    end

    describe "mass-update/create/destroy items" do

      let(:item1) do
        SecurityPolicyItem.create!(:role_id => 0,
                                   :permission_name => 'a permission')
      end
      let(:item2) do
        SecurityPolicyItem.create!(:role_id => 0,
                                   :permission_name => 'another permission')
      end
      let(:item3) do
        SecurityPolicyItem.create!(:role_id => 1,
                                   :permission_name => 'a permission')
      end
      let(:item4) do
        SecurityPolicyItem.create!(:role_id => 2,
                                   :permission_name => 'a permission')
      end
      let(:item5) do
        SecurityPolicyItem.create!(:role_id => 2,
                                   :permission_name => 'another permission')
      end

      it "can mass-update or mass-destroy with a hash of attribute hashes" do
        SecurityPolicyItem.mass_manage!({
          '0' => {:id => item1.to_param, :role_id => '3', :_destroy => '0'},
          '1' => {:id => item2.to_param, :role_id => '3'},
          '2' => {:id => item3.to_param,
                  :permission_name => 'some other permission'},
          '3' => {:id => item4.to_param, :_destroy => '1'},
          '4' => {:id => item5.to_param, :_destroy => '1'},
          '5' => {:role_id => '1', :permission_name => 'another permission'},
          '6' => {:role_id => '2', :permission_name => 'some other permission'}
        })
        SecurityPolicyItem.find(item1.id).role_id.should == 3
        SecurityPolicyItem.find(item1.id).
          permission_name.should == 'a permission'
        SecurityPolicyItem.find(item2.id).role_id.should == 3
        SecurityPolicyItem.find(item2.id).
          permission_name.should == 'another permission'
        SecurityPolicyItem.find(item3.id).role_id.should == 1
        SecurityPolicyItem.find(item3.id).
          permission_name.should == 'some other permission'
        SecurityPolicyItem.find_by_id(item4.id).should be_nil
        SecurityPolicyItem.find_by_id(item5.id).should be_nil
        SecurityPolicyItem.find_by_role_id_and_permission_name(
          1, 'another permission'
        ).should_not be_nil
        SecurityPolicyItem.find_by_role_id_and_permission_name(
          2, 'some other permission'
        ).should_not be_nil
      end

      it "can mass-update or mass-destroy with an array of attribute hashes" do
        SecurityPolicyItem.mass_manage!([
          {:id => item1.to_param, :role_id => '3', :_destroy => '0'},
          {:id => item2.to_param, :role_id => '3'},
          {:id => item3.to_param, :permission_name => 'some other permission'},
          {:id => item4.to_param, :_destroy => '1'},
          {:id => item5.to_param, :_destroy => '1'},
          {:role_id => '1', :permission_name => 'another permission'},
          {:role_id => '2', :permission_name => 'some other permission'}
        ])
        SecurityPolicyItem.find(item1.id).role_id.should == 3
        SecurityPolicyItem.find(item1.id).
          permission_name.should == 'a permission'
        SecurityPolicyItem.find(item2.id).role_id.should == 3
        SecurityPolicyItem.find(item2.id).
          permission_name.should == 'another permission'
        SecurityPolicyItem.find(item3.id).role_id.should == 1
        SecurityPolicyItem.find(item3.id).
          permission_name.should == 'some other permission'
        SecurityPolicyItem.find_by_id(item4.id).should be_nil
        SecurityPolicyItem.find_by_id(item5.id).should be_nil
        SecurityPolicyItem.find_by_role_id_and_permission_name(
          1, 'another permission'
        ).should_not be_nil
        SecurityPolicyItem.find_by_role_id_and_permission_name(
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

    end

  end
end
