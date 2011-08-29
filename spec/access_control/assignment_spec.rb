require 'spec_helper'
require 'access_control/assignment'
require 'access_control/configuration'
require 'access_control/node'
require 'access_control/role'

module AccessControl

  describe Assignment do

    let(:manager) { Manager.new }

    before do
      AccessControl.config.stub(:default_roles_on_create).and_return(nil)
      AccessControl.stub(:manager).and_return(manager)
      manager.stub(:can_assign_or_unassign?).and_return(true)
    end

    it "can be created with valid attributes" do
      Assignment.create!(
        :node => stub_model(AccessControl::Node),
        :principal => stub_model(AccessControl::Principal),
        :role => stub_model(AccessControl::Role)
      )
    end

    it "validates presence of node_id" do
      Assignment.new.should have(1).error_on :node_id
    end

    it "validates presence of role_id" do
      Assignment.new.should have(1).error_on :role_id
    end

    it "validates presence of principal_id" do
      Assignment.new.should have(1).error_on :principal_id
    end

    it "validates uniqueness of role_id, principal_id and node_id" do
      Assignment.create!(:node_id => 0, :principal_id => 0, :role_id => 0)
      Assignment.new(:node_id => 0, :principal_id => 0, :role_id => 0).
        should have(1).error_on(:role_id)
      Assignment.new(:node_id => 0, :principal_id => 0, :role_id => 1).
        should have(:no).errors_on(:role_id)
      Assignment.new(:node_id => 0, :principal_id => 1, :role_id => 0).
        should have(:no).errors_on(:role_id)
      Assignment.new(:node_id => 1, :principal_id => 0, :role_id => 0).
        should have(:no).errors_on(:role_id)
    end

    describe "role validation" do

      describe "Node conformance with expected interface" do
        it_has_instance_method(Node, :global?)
      end

      describe "Role conformance with expected interface" do
        it_has_instance_method(Role, :local)
      end

      describe "for global node" do

        let(:node) { stub_model(Node, :global? => true) }

        it "accepts a role if it is global assignable" do
          Assignment.new(:node => node,
                         :role => stub_model(Role, :global => true)).
                         should have(:no).errors_on(:role_id)
        end

        it "rejects a role if it is not global assignable" do
          Assignment.new(:node => node,
                         :role => stub_model(Role, :global => false)).
                         should have(1).errors_on(:role_id)
        end

      end

      describe "for local nodes" do

        let(:node) { stub_model(Node, :global? => false) }

        it "accepts a role if it is local assignable" do
          Assignment.new(:node => node,
                         :role => stub_model(Role, :local => true)).
                         should have(:no).errors_on(:role_id)
        end

        it "rejects a role if it is not local assignable" do
          Assignment.new(:node => node,
                         :role => stub_model(Role, :local => false)).
                         should have(1).errors_on(:role_id)
        end

      end

      describe "assignment security" do

        describe "Manager conformance with expected interface" do
          it_has_instance_method(Manager, :can_assign_or_unassign?)
          it_has_instance_method(Manager, :verify_assignment!)
        end

        let(:node) { stub_model(Node) }
        let(:role) { stub_model(Role, :name => 'some_role', :local => true) }

        it "doesn't break the validation when there's no node or role" do
          # The validation process should not call this method when there's no
          # role or node.
          manager.should_not_receive(:can_assign_or_unassign?).
            with(nil, nil)
        end

        it "validates fine if the user can assign" do
          manager.should_receive(:can_assign_or_unassign?).
            with(node, role).and_return(true)
          Assignment.new(:node => node, :role => role).
            should have(:no).error_on(:role_id)
        end

        it "gets an error if the user cannot assign" do
          manager.should_receive(:can_assign_or_unassign?).
            with(node, role).and_return(false)
          Assignment.new(:node => node, :role => role).
            should have(1).error_on(:role_id)
        end

        it "validates fine if user cannot assign but the verification is "\
           "skipped" do
          assignment = Assignment.new(:node => node, :role => role)
          assignment.skip_assignment_verification!
          manager.should_not_receive(:can_assign_or_unassign?)
          assignment.should have(:no).error_on(:role_id)
        end

        describe "on destroy" do

          let(:assignment) { stub_model(Assignment,
                                        :node => node,
                                        :role => role,
                                        :destroy_without_callbacks => nil) }

          it "destroys fine if the user can unassign" do
            manager.should_receive(:verify_assignment!).with(node, role)
            assignment.destroy
          end

          it "calls manager.verify_assignment! (which raises Unauthorized)" do
            manager.should_receive(:verify_assignment!).with(node, role).
              and_raise(Unauthorized)
            lambda { assignment.destroy }.should raise_exception(Unauthorized)
          end

        end

      end

    end

    describe ".with_roles" do
      it "filters out assignments which haven't one of the roles" do
        role1 = stub('role', :id => "role1's id")
        role2 = stub('role', :id => "role2's id")
        Assignment.with_roles([role1, role2]).proxy_options.should == {
          :conditions => { :role_id => ["role1's id", "role2's id"] }
        }
      end
    end

    describe "assignments for management" do

      before do
        Node.create_global_node!
        roles = [
          @role1 = Role.create!(:name => 'role1'),
          @role2 = Role.create!(:name => 'role2'),
          @role3 = Role.create!(:name => 'role3')
        ]
        principals = [
          @principal1 = Principal.create!(
            :subject_type => 'SubjectType',
            :subject_id => 0
          ),
          @principal2 = Principal.create!(
            :subject_type => 'SubjectType',
            :subject_id => 1
          ),
          @principal3 = Principal.create!(
            :subject_type => 'SubjectType',
            :subject_id => 2
          ),
          @principal4 = Principal.create!(
            :subject_type => 'SubjectType',
            :subject_id => 3
          )
        ]
        @node = Node.create!(:securable_type => 'SecurableType',
                            :securable_id => 0)
        @item1 = Assignment.create!(
          :node => @node, :principal => @principal1, :role => @role1
        )
        @item2 = Assignment.create!(
          :node => @node, :principal => @principal2, :role => @role2
        )
        Assignment.create!(:node_id => @node.id + 1,
                          :principal => @principal4, :role => @role1)
        @items = Assignment.items_for_management(@node, roles)
      end

      it "return one key for each different principal id with some role "\
        "assigned to the node" do
        @items.size.should == 2
      end

      it "returns one value for each role passed in" do
        @items[@principal1.id].size.should == 3
        @items[@principal2.id].size.should == 3
      end

      it "returns assignments that already exist for the node" do
        @items[@principal1.id].first.should == @item1
        @items[@principal2.id].second.should == @item2
      end

      it "returns new assignments when there's no assignment created" do
        @items[@principal1.id].second.should be_new_record
        @items[@principal1.id].second.node_id.should == @node.id
        @items[@principal1.id].second.role_id.should == @role2.id
        @items[@principal1.id].third.should be_new_record
        @items[@principal1.id].third.node_id.should == @node.id
        @items[@principal1.id].third.role_id.should == @role3.id

        @items[@principal2.id].first.should be_new_record
        @items[@principal2.id].first.node_id.should == @node.id
        @items[@principal2.id].first.role_id.should == @role1.id
        @items[@principal2.id].third.should be_new_record
        @items[@principal2.id].third.node_id.should == @node.id
        @items[@principal2.id].third.role_id.should == @role3.id
      end

    end

  end

end
