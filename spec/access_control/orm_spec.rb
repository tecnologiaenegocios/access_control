require 'spec_helper'

module AccessControl
  module ORM
    describe Base do
      let(:orm_class) { Class.new(Base).new }
      describe Base.instance_method(:full_pk).name do
        before { orm_class.stub(:pk => 'pk',
                                :quoted_table_name => '`table_name`') }
        subject { orm_class.method(:full_pk).call }

        it { should == '`table_name`.pk' }
      end
    end
  end
end
