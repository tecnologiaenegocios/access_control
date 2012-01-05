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
      let(:db)          { AccessControl.db }

      subject { Restricter.new(orm_class).sql_query_for(permissions) }

      before do
        orm_class.stub(:pk_name).and_return(:pk)
        orm_class.stub(:table_name).and_return(:table_name)
        orm_class.stub(:name).and_return('ModelName')
        AccessControl.stub(:manager).and_return(manager)
        AccessControl.stub(:global_node).and_return(global_node)
      end

      context "when the user has all permissions in global node" do
        before do
          manager.stub(:can?).with(permissions, global_node).and_return(true)
        end

        it { should == db[orm_class.table_name].select(orm_class.pk_name).sql }
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

        it { should == AccessControl.ac_nodes.
             join_table(:left, :ac_effective_assignments, :node_id => :id).
             filter(:securable_type => orm_class.name,
                    :principal_id => [1,2],
                    :role_id => [1,2]).
             select(:securable_id).sql }
      end
    end
  end
end
