require 'spec_helper'
require 'access_control/assignment'
require 'access_control/behavior'
require 'access_control/configuration'
require 'access_control/node'
require 'access_control/role'

module AccessControl

  describe Assignment do

    let(:manager) { Manager.new }

    before do
      AccessControl.config.stub(:default_roles_on_create).and_return(Set.new)
      AccessControl.stub(:manager).and_return(manager)
    end

    it "is extended with AccessControl::Ids" do
      singleton_class = (class << Assignment; self; end)
      singleton_class.should include(AccessControl::Ids)
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

      context "for global node" do

        let(:node) { stub("Node", :global? => true, :id => 12345) }

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

        let(:node) { stub("Node", :global? => false, :id => 12345) }

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

        let(:node) { stub("Node", :id => 12345) }
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
      let(:a1) do
        r = Assignment.new(:principal_id => 0, :node_id => 0, :role_id => 1)
        r.save(false)
        r
      end
      let(:a2) do
        r = Assignment.new(:principal_id => 0, :node_id => 0, :role_id => 2)
        r.save(false)
        r
      end
      before { a1; a2 }
      it "returns assignments for the given role" do
        Assignment.with_roles(1).should include(a1)
      end
      it "rejects assignments for different roles of the specified" do
        Assignment.with_roles(1).should_not include(a2)
      end
      it "accepts an array" do
        collection = Assignment.with_roles([1, 2])
        collection.should include(a1)
        collection.should include(a1)
      end
    end

    describe ".assigned_to" do
      let(:a1) do
        r = Assignment.new(:principal_id => 1, :node_id => 0, :role_id => 0)
        r.save(false)
        r
      end
      let(:a2) do
        r = Assignment.new(:principal_id => 2, :node_id => 0, :role_id => 0)
        r.save(false)
        r
      end
      before { a1; a2 }
      it "returns assignments for the given principal" do
        Assignment.assigned_to(1).should include(a1)
      end
      it "rejects assignments for different principals of the specified" do
        Assignment.assigned_to(1).should_not include(a2)
      end
      it "accepts an array" do
        collection = Assignment.assigned_to([1, 2])
        collection.should include(a1)
        collection.should include(a1)
      end
    end

    describe ".granting" do

      let(:roles_proxy) { stub('roles proxy', :ids => [1]) }
      let(:a1) do
        r = Assignment.new(:role_id => 1, :node_id => 1, :principal_id => 1)
        r.save(false)
        r
      end
      let(:a2) do
        r = Assignment.new(:role_id => 2, :node_id => 1, :principal_id => 1)
        r.save(false)
        r
      end

      before do
        a1; a2
        Role.stub(:for_permission).and_return(roles_proxy)
      end

      it "gets all roles for the specified permission" do
        Role.should_receive(:for_permission).with('some permission').
          and_return(roles_proxy)
        Assignment.granting('some permission')
      end

      it "gets all role ids from the proxy" do
        roles_proxy.should_receive(:ids)
        Assignment.granting('some permission')
      end

      it "returns assignments with the relevant role_id" do
        Assignment.granting('some permission').should include(a1)
      end

      it "rejects assignments without the relevant role_id" do
        Assignment.granting('some permission').should_not include(a2)
      end
    end

    describe ".granting_for_principal" do
      let(:granting_proxy) { stub('granting proxy') }
      let(:assignment_proxy) { stub('assignment proxy') }

      before do
        Assignment.stub(:granting).and_return(granting_proxy)
        granting_proxy.stub(:assigned_to).and_return(assignment_proxy)
      end

      it "calls .granting with permission provided" do
        Assignment.should_receive(:granting).with('permission').
          and_return(granting_proxy)
        Assignment.granting_for_principal('permission', 'principal')
      end

      it "calls .assigned_to with principal provided in the resulting object" do
        granting_proxy.should_receive(:assigned_to).with('principal')
        Assignment.granting_for_principal('permission', 'principal')
      end

      it "returns whatever .assigned_to returns" do
        Assignment.granting_for_principal('permission', 'principal').should ==
          assignment_proxy
      end
    end

    describe "assignments for management" do

      before do
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

        @node = stub(:securable_type => 'SecurableType',
                     :securable_id => 0, :id => 12345)
        Node.stub(:fetch).with(@node.id, nil).and_return(@node)

        @item1 = Assignment.create!(
          :node => @node, :principal => @principal1, :role => @role1
        )
        @item2 = Assignment.create!(
          :node => @node, :principal => @principal2, :role => @role2
        )

        inexistent_node_id = @node.id + 1
        Node.stub(:fetch).with(inexistent_node_id, nil).and_return(nil)

        Assignment.create!(:node_id => inexistent_node_id,
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
