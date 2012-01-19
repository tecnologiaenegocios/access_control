require 'spec_helper'

module AccessControl
  describe SecurityPolicyItem do
    describe ".with_permissions" do
      let!(:item1) do
        SecurityPolicyItem.create(:role_id => 0, :permission => 'permission 1')
      end

      let!(:item2) do
        SecurityPolicyItem.create(:role_id => 0, :permission => 'permission 2')
      end

      it "returns items for the specified permission" do
        SecurityPolicyItem.with_permissions('permission 1').should include(item1)
      end

      it "rejects items for not specified permissions" do
        SecurityPolicyItem.with_permissions('permission 1').
          should_not include(item2)
      end

      it "accepts an array" do
        collection =
          SecurityPolicyItem.with_permissions(['permission 1', 'permission 2'])
        collection.should include(item1)
        collection.should include(item2)
      end

      it "accepts a set" do
        collection = SecurityPolicyItem.
          with_permissions(Set['permission 1', 'permission 2'])
        collection.should include(item1)
        collection.should include(item2)
      end
    end
  end
end
