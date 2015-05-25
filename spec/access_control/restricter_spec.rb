require 'spec_helper'
require 'access_control/restricter'
require 'access_control/restriction'

module AccessControl
  describe Restricter do

    # A Restricter can build a SQL query for getting the permitted ids from a
    # table.  This SQL can further be used as a subquery for filtering outer
    # queries.

    describe "sql_query_for" do
      let(:orm_class)        { Class.new }
      let(:manager)          { stub('manager') }
      let(:global_node)      { stub('global node') }
      let(:permissions)      { [stub(:name => 'permission')] }

      subject { Restricter.new(orm_class).sql_query_for(permissions) }

      before do
        orm_class.stub(:all_sql).and_return('sti-aware class subquery')
        AccessControl.stub(:manager).and_return(manager)
        AccessControl.stub(:global_node).and_return(global_node)
      end

      context "when the user has all permissions in global node" do
        before do
          manager.stub(:can?).with(permissions, global_node).and_return(true)
        end

        it { should == orm_class.all_sql }
      end
    end
  end
end
