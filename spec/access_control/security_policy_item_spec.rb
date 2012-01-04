require 'spec_helper'

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

  end
end
