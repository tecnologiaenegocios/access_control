require 'spec_helper'
require 'access_control/behavior'
require 'access_control/security_policy_item'

module AccessControl
  describe SecurityPolicyItem do

    it "is extended with AccessControl::Ids" do
      singleton_class = (class << SecurityPolicyItem; self; end)
      singleton_class.should include(AccessControl::Ids)
    end

    describe ".with_permission" do
      let!(:item1) do
        SecurityPolicyItem.create!(:role_id => 0, :permission => 'permission 1')
      end

      let!(:item2) do
        SecurityPolicyItem.create!(:role_id => 0, :permission => 'permission 2')
      end

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
        SecurityPolicyItem.create!(:role_id => 1,
                                   :permission => 'a permission')
      end
      let(:item2) do
        SecurityPolicyItem.create!(:role_id => 1,
                                   :permission => 'another permission')
      end
      let(:item3) do
        SecurityPolicyItem.create!(:role_id => 2,
                                   :permission => 'a permission')
      end
      let(:item4) do
        SecurityPolicyItem.create!(:role_id => 3,
                                   :permission => 'a permission')
      end
      let(:item5) do
        SecurityPolicyItem.create!(:role_id => 2,
                                   :permission => 'another permission')
      end

      let(:parameters) do
        {
          '0' => {},
          '1' => {:id => item1.to_param},
          '2' => {:id => item2.to_param, :_destroy => '0'},
          '3' => {:id => item3.to_param, :_destroy => '1'},
          '4' => {:id => item4.to_param, :role_id => '4'},
          '5' => {:id => item5.to_param,
                  :permission => 'some other permission'},
          '6' => {:role_id => '5', :permission => 'unique permission'},
          # New item, but should not create because _destroy == 1.
          '7' => {:role_id => '5',
                  :permission => 'other unique permission',
                  :_destroy => '1'}
        }
      end

      [
        ['using a hash of attribute hashes',   Proc.new {|p| p }],
        ['using an array of attribute hashes', Proc.new {|p| p.values } ]
      ].each do |type_description, type_proc|
        describe "mass-update or mass-destroy #{type_description}" do

          let(:effective_parameters) { type_proc[parameters] }

          def do_mass_manage
            SecurityPolicyItem.mass_manage!(effective_parameters)
          end

          before do
            pending "Waiting for review"
            do_mass_manage
          end

          it "should not change item 1 since it is not being changed" do
            attrs = item1.attributes.symbolize_keys
            attrs.delete(:lock_version)
            attrs.should == {
              :id => item1.id, :role_id => 1, :permission => 'a permission'
            }
          end

          it "should not destroy item 2 since its _destroy flag isn't set" do
            SecurityPolicyItem.find(item2.id).should == item2
          end

          it "should destroy item 3" do
            SecurityPolicyItem.find_by_id(item3.id).should be_nil
          end

          it "should have changed the role of item 4" do
            item4.reload.role_id.should == 4
          end

          it "should have changed the permission of item 5" do
            item5.reload.permission.should == 'some other permission'
          end

          it "should have created a new item" do
            SecurityPolicyItem.find(
              :first, :conditions => { :role_id => 5,
                                       :permission => 'unique permission' }
            ).should_not be_nil
          end

          it "should not have created a new item if _destroy was set" do
            SecurityPolicyItem.find(
              :first,
              :conditions => { :role_id => 5,
                               :permission => 'other unique permission' }
            ).should be_nil
          end

          context "filtering roles" do
            def do_mass_manage
              SecurityPolicyItem.mass_manage!(effective_parameters,
                                              roles_allowed)
            end

            context "while creating" do
              let(:roles_allowed) { [
                stub(:id => 1), stub(:id => 2), stub(:id => 4), stub(:id => 5)
              ] }

              it "skips items of that role" do
                SecurityPolicyItem.find(
                  :first, :conditions => { :role_id => 3,
                                           :permission => 'unique permission' }
                ).should be_nil
              end
            end

            context "while updating" do
              context "an item from any role to a filtered role" do
                let(:roles_allowed) { [
                  stub(:id => 1), stub(:id => 2), stub(:id => 3), stub(:id => 5)
                ] }

                it "skips updating" do
                  item4.reload.role_id.should == 3
                end
              end

              context "an item of that role" do
                let(:roles_allowed) { [
                  stub(:id => 1), stub(:id => 3), stub(:id => 4), stub(:id => 5)
                ] }

                it "skips updating" do
                  item5.reload.permission.should == 'another permission'
                end
              end
            end

            context "while destroying" do
              let(:roles_allowed) { [
                stub(:id => 1), stub(:id => 3), stub(:id => 4), stub(:id => 5)
              ] }
              
              it "skips destroying" do
                SecurityPolicyItem.find(item3.id).should == item3
              end
            end
          end

        end
      end

      it "raises ActiveRecord::RecordNotFound if some item is not found" do
        lambda {
          SecurityPolicyItem.mass_manage!([
            {:id => '-10', :role_id => '3', :_destroy => '0'}
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
        # Needed to sweep any assignment/role/item attached to the global node.
        SecurityPolicyItem.stub(:find).and_return(item1)
        AccessControl::Node.should_receive(:clear_global_cache).once
        SecurityPolicyItem.mass_manage!([
          {:id => item1.to_param, :role_id => '3'}
        ])
      end

    end

    describe "items for management" do

      before do
        pending "Waiting for review"
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
