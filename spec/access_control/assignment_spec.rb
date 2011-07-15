require 'spec_helper'
require 'access_control/assignment'
require 'access_control/configuration'
require 'access_control/node'
require 'access_control/role'

module AccessControl

  describe Assignment do

    let(:manager) { SecurityManager.new }

    before do
      AccessControl.config.stub(:default_roles_on_create).and_return(nil)
      AccessControl.stub(:security_manager).and_return(manager)
    end

    it "can be created with valid attributes" do
      Assignment.stub(:skip_role_verification? => true)
      Assignment.create!(
        :node => stub_model(AccessControl::Node),
        :principal => stub_model(AccessControl::Principal),
        :role => stub_model(AccessControl::Role)
      )
    end

    it "is not securable" do
      Assignment.securable?.should be_false
    end

    it "validates uniqueness of role_id, principal_id and node_id" do
      Assignment.stub(:skip_role_verification? => true)
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

    describe "validation" do

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

        describe "Node conformance with expected interface" do
          it_has_instance_method(Node, :global?)
        end

        describe "Role conformance with expected interface" do
          it_has_instance_method(Role, :name)
        end

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

        describe "Node conformance with expected interface" do
          it_has_instance_method(Node, :current_roles)
          it_has_instance_method(Node, :has_permission?)
        end

        describe "Role conformance with expected interface" do
          it_has_instance_method(Role, :local)
        end

        let(:node) do
          Node.create!(:securable_type => 'Foo', :securable_id => 1).reload
        end
        let(:role) { stub_model(Role, :name => 'some_role', :local => true) }
        let(:other_role) { stub_model(Role, :name => 'other_role',
                                      :local => true) }

        before do
          manager.stub(:verify_access!)
          node.stub(:current_roles).and_return(Set.new([role]))
        end

        describe "when the principal has 'share_own_roles'" do

          before do
            node.should_receive(:has_permission?).
              with('share_own_roles').any_number_of_times.
              and_return(true)
            node.should_receive(:has_permission?).
              with('grant_roles').any_number_of_times.
              and_return(false)
          end

          it "saves fine if the role belongs to the principal" do
            assignment = Assignment.new(:node => node, :role => role,
                                        :principal_id => 1)
            lambda { assignment.save! }.should_not raise_exception
          end

          it "raises Unauthorized if a role that doesn't belong to the "\
             "principal is assigned" do
            assignment = Assignment.new(:node => node, :role => other_role,
                                        :principal_id => 1)
            lambda { assignment.save! }.should raise_exception(Unauthorized)
          end

          describe "when destroying" do

            it "destroys fine if the role belongs to the principal" do
              assignment = Assignment.create!(:node => node, :role => role,
                                              :principal_id => 1)
              lambda { assignment.destroy }.should_not raise_exception
            end

            it "raises Unauthorized if has a role that doesn't belong to the "\
               "principal" do
              node.stub!(:current_roles).and_return(Set.new([other_role]))
              assignment = Assignment.create!(:node => node,
                                              :role => other_role,
                                              :principal_id => 1)
              node.stub!(:current_roles).and_return(Set.new([role]))
              lambda { assignment.destroy }.should raise_exception(Unauthorized)
            end

          end

        end

        describe "when the principal has 'grant_roles'" do

          before do
            node.should_receive(:has_permission?).
              with('grant_roles').any_number_of_times.
              and_return(true)
          end

          it "saves fine even if the role doesn't belongs to the principal" do
            Assignment.create!(:node => node, :role => other_role,
                               :principal_id => 1)
          end

          it "destroys even if the role doesn't belongs to the principal" do
            assignment = Assignment.create!(:node => node, :role => other_role,
                                            :principal_id => 1)
            lambda { assignment.destroy }.should_not raise_exception
          end

        end

        describe "when the principal hasn't 'grant_roles' neither "\
                 "'share_own_roles'" do

          it "raises Unauthorized when saving" do
            node.should_receive(:has_permission?).
              with('grant_roles').
              and_return(false)
            node.should_receive(:has_permission?).
              with('share_own_roles').
              and_return(false)
            lambda {
              Assignment.create!(:node => node, :role => other_role,
                                :principal_id => 1)
            }.should raise_exception(Unauthorized)
          end

          it "raises Unauthorized when destroying" do
            node.should_receive(:has_permission?).
              with('grant_roles').
              and_return(true)
            assignment = Assignment.create!(:node => node, :role => other_role,
                                            :principal_id => 1)
            node.should_receive(:has_permission?).
              with('grant_roles').
              and_return(false)
            node.should_receive(:has_permission?).
              with('share_own_roles').
              and_return(false)
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
        Assignment.stub(:skip_role_verification? => true)
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
