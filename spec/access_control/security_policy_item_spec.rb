require 'spec_helper'

module AccessControl
  describe SecurityPolicyItem do
    it "cannot be wrapped by a security proxy" do
      SecurityPolicyItem.securable?.should be_false
    end
  end
end
