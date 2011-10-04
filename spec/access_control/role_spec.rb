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

    describe "assignment destruction" do

      let(:assignment) do
        stub_model(Assignment, :[]= => true, :save => true)
      end

      let(:role) do
        Role.new(:name => 'the role name')
      end

      before do
        Object.const_set('TestPoint', stub('testpoint'))
        role.assignments << assignment
      end

      after do
        Object.send(:remove_const, 'TestPoint')
      end

      it "destroys assignments when it is destroyed" do
        assignment.should_receive(:destroy)
        role.destroy
      end

      it "destroys the assignment in a unrestricted block" do
        TestPoint.should_receive(:before_yield).ordered
        TestPoint.should_receive(:on_destroy).ordered
        TestPoint.should_receive(:after_yield).ordered
        manager.instance_eval do
          def without_assignment_restriction
            TestPoint.before_yield
            yield
            TestPoint.after_yield
          end
        end
        assignment.instance_eval do
          def destroy
            TestPoint.on_destroy
          end
        end
        role.destroy
      end

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
