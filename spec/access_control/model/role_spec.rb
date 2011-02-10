require 'spec_helper'

module AccessControl::Model
  describe Role do
    it "can be created with valid attributes" do
      Role.create!(:name => 'the role name')
    end
    it "cannot be wrapped by a security proxy" do
      Role.securable?.should be_false
    end
  end
end
