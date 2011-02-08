require 'spec_helper'

module AccessControl
  module Model
    describe SecurityPolicyItem do
      it "cannot be wrapped by a security proxy" do
        SecurityPolicyItem.new.securable?.should be_false
      end
    end
  end
end
