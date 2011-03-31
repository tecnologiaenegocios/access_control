require 'spec_helper'

module AccessControl
  describe Role do

    it "validates uniqueness of name" do
      Role.create!(:name => 'the role name')
      Role.new(:name => 'the role name').should have(1).error_on(:name)
    end

    it "can be created with valid attributes" do
      Role.create!(:name => 'the role name')
    end

    it "cannot be wrapped by a security proxy" do
      Role.securable?.should be_false
    end

    it "destroys assignments when it is destroyed" do
      role = Role.create!(:name => 'the role name')
      Principal.create_anonymous_principal!
      Node.create_global_node!
      Assignment.create!(:role => role,
                         :node => Node.global,
                         :principal => Principal.anonymous)
      role.destroy
      Assignment.count.should == 0
    end

    it "destroys security policy items when it is destroyed" do
      role = Role.create!(:name => 'the role name')
      SecurityPolicyItem.create!(:role => role,
                                 :permission_name => 'some permission')
      role.destroy
      SecurityPolicyItem.count.should == 0
    end

  end
end
