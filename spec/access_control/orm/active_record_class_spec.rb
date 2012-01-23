require 'access_control/orm/active_record_class'

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

      let(:instance) { stub }

      let(:orm) { ActiveRecordClass.new(model) }

      describe ".name" do
        subject { orm.name }
        it { should == "ModelName" }
      end

      describe ".pk_name" do
        subject { orm.pk_name }
        it { should == :pk }
      end

      describe ".table_name" do
        subject { orm.table_name }
        it { should == :table_name }
      end

      describe ".column_names" do
        before  { model.stub(:column_names).and_return(['foo', 'bar']) }
        subject { orm.column_names }
        it { should == [:foo, :bar] }
      end

      describe ".[](pk)" do
        before  { model.stub(:find_by_pk).with('pk').and_return('value') }
        subject { orm['pk'] }
        it { should == 'value' }
      end

      describe ".values_at(*pks)" do
        let(:pks) { [1,2,3] }
        before  { model.stub(:all).with(:conditions => { :pk => pks }).
                  and_return(['value']) }
        subject { orm.values_at(*pks) }
        it { should == ['value'] }
      end

      describe ".include?(pk)" do
        before  { model.stub(:exists?).with('pk').and_return('the answer') }
        subject { orm.include?('pk') }
        it { should == 'the answer' }
      end

      describe ".size" do
        before  { model.stub(:count).and_return('the number of items') }
        subject { orm.size }
        it { should == 'the number of items' }
      end

      describe ".values" do
        before  { model.stub(:scoped).with({}).
                  and_return('all active record objects as a scope') }
        subject { orm.values }
        it { should == 'all active record objects as a scope' }
      end

      describe ".new" do
        # This method only need to return an ordinary instance, which must
        # respond to readers and writers corresponding to the column names.  In
        # the case of ActiveRecord this is just a regular instantiation.
        before  { model.stub(:new).and_return(instance) }
        subject { orm.new }
        it { should be instance }
      end

      describe ".subset(subset_name, *args)" do
        # By calling this method the caller expects to get a subset of the
        # whole set of objects, and will want to iterate over it.  ActiveRecord
        # scopes fit this expectation.  This method should not be abused as a
        # general way to send calls to the underlying ORM class.
        it "just forwards the subset as a scope or class method call" do
          p1, p2 = stub, stub
          returned_value = stub
          model.stub(:some_scope).with(p1, p2).and_return(returned_value)
          orm.subset(:some_scope, p1, p2).should be returned_value
        end
      end

      describe ".instance_eql?(instance, other)" do
        let(:instance1) { stub }
        let(:instance2) { stub }

        context "when instances are equal" do
          before  { instance1.stub(:==).with(instance2).and_return(true) }
          subject { orm.instance_eql?(instance1, instance2) }
          it { should be_true }
        end

        context "when instances aren't equal" do
          before  { instance1.stub(:==).with(instance2).and_return(false) }
          subject { orm.instance_eql?(instance1, instance2) }
          it { should be_false }
        end
      end

      describe ".persist(instance)" do
        # This method should return true if the instance was persisted,
        # otherwise it should return false.
        #
        # Since ActiveRecord does exactly that, the implementation simply
        # delegates the call.
        before  { instance.stub(:save).and_return('the answer') }
        subject { orm.persist(instance) }
        it { should == 'the answer' }
      end

      describe ".persisted?(instance)" do
        context "when the instance is a new record" do
          before  { instance.stub(:new_record?).and_return(true) }
          subject { orm.persisted?(instance) }
          it { should be_false }
        end

        context "when the instance isn't a new record" do
          before  { instance.stub(:new_record?).and_return(false) }
          subject { orm.persisted?(instance) }
          it { should be_true }
        end
      end

      describe ".delete(instance)" do
        it "destroys the instance" do
          instance.should_receive(:destroy)
          orm.delete(instance)
        end
      end
    end
  end
end
