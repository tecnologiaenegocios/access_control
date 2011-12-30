require 'spec_helper'
require 'access_control/restricter'
require 'access_control/restriction'

module AccessControl
  describe Restricter do

    # A Restricter can build a SQL query for getting the permitted ids from a
    # table.  This SQL can further be used as a subquery for filtering outer
    # queries.

    describe "sql_query_for" do
      let(:orm_class)   { Class.new }
      let(:manager)     { stub('manager') }
      let(:global_node) { stub('global node') }
      let(:permissions) { ['permissions'] }

      subject { Restricter.new(orm_class).sql_query_for(permissions) }

      before do
        orm_class.stub(:pk).and_return('pk')
        orm_class.stub(:quoted_table_name).and_return('`table_name`')
        AccessControl.stub(:manager).and_return(manager)
        AccessControl.stub(:global_node).and_return(global_node)
      end

      context "when the user has all permissions in global node" do
        before do
          manager.stub(:can?).with(permissions, global_node).and_return(true)
        end

        it { should == "SELECT pk FROM `table_name`" }
      end

      context "when the user doesn't have all permissions in global node" do
        let(:role1) { stub(:id => 1) }
        let(:role2) { stub(:id => 2) }
        let(:principal1) { stub(:id => 1) }
        let(:principal2) { stub(:id => 2) }

        before do
          manager.stub(:can?).with(permissions, global_node).and_return(false)
          Role.stub(:for_all_permissions).with(permissions).
            and_return([role1, role2])
          manager.stub(:principals).and_return([principal1, principal2])
        end

        it { should == \
            "SELECT node_id FROM `ac_effective_assignments` "\
              "WHERE role_id IN (1,2) AND principal_id IN (1,2)" }
      end
    end
  end
end
