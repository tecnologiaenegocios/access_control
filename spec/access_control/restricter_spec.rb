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
      let(:db)               { AccessControl.db }

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
    end
  end
end
