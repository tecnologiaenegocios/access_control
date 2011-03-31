require 'spec_helper'

module AccessControl

  describe Assignment do
    it "can be created with valid attributes" do
      Assignment.create!(
        :node => stub_model(AccessControl::Node),
        :principal => stub_model(AccessControl::Principal),
        :role => stub_model(AccessControl::Role)
      )
    end
    it "cannot be wrapped by a security proxy" do
      Assignment.securable?.should be_false
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
