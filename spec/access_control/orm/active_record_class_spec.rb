require 'access_control/orm'

module AccessControl
  module ORM
    describe ActiveRecordClass do
      let(:model) do
        stub('model', {
          :name        => 'ModelName',
          :table_name  => "table_name",
          :primary_key => "pk",
        })
      end

      let(:orm) { ActiveRecordClass.new(model) }

      describe "#name" do
        subject { orm.name }
        it { should == :ModelName }
      end

      describe "#pk" do
        subject { orm.pk }
        it { should == :pk }
      end

      describe "#table_name" do
        subject { orm.table_name }
        it { should == :table_name }
      end
    end
  end
end
