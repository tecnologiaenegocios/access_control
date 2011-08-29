require 'spec_helper'
require 'access_control/role'

module AccessControl
  describe Role do

    let(:manager) { Manager.new }

    before do
      AccessControl.stub(:manager).and_return(manager)
    end

    it "validates presence of name" do
      Role.new.should have(1).error_on(:name)
    end

    it "validates uniqueness of name" do
      Role.create!(:name => 'the role name')
      Role.new(:name => 'the role name').should have(1).error_on(:name)
    end

    it "can be created with valid attributes" do
      Role.create!(:name => 'the role name')
    end

    it "destroys assignments when it is destroyed" do
      Principal.create_anonymous_principal!
      Node.create_global_node!
      manager.stub(:can_assign_or_unassign?).and_return(true)
      role = Role.create!(:name => 'the role name')
      Assignment.create!(:role => role,
                         :node => Node.global,
                         :principal => Principal.anonymous)
      role.destroy
      Assignment.count.should == 0
    end

    it "destroys security policy items when it is destroyed" do
      role = Role.create!(:name => 'the role name')
      SecurityPolicyItem.create!(:role => role,
                                 :permission => 'some permission')
      role.destroy
      SecurityPolicyItem.count.should == 0
    end

    describe "#local_assignables" do

      it "returns only roles with local = true" do
        r1 = Role.create!(:name => 'local unassignable', :local => false)
        r2 = Role.create!(:name => 'local assignable', :local => true)
        Role.local_assignables.should == [r2]
      end

    end

    describe "#global_assignables" do

      it "returns only roles with global = true" do
        r1 = Role.create!(:name => 'global unassignable', :global => false)
        r2 = Role.create!(:name => 'global assignable', :global => true)
        Role.global_assignables.should == [r2]
      end

    end

    describe "#permissions" do
      it "returns the permissions from its security policy items" do
        r = Role.new
        r.security_policy_items = [
          SecurityPolicyItem.new(:permission => 'some permission'),
          SecurityPolicyItem.new(:permission => 'other permission')
        ]
        r.permissions.should == Set.new(['other permission', 'some permission'])
      end
    end

  end
end
