require 'access_control/orm/sequel_class'
require 'delegate'

module AccessControl
  module ORM
    describe SequelClass do

      let(:model) do
        stub('model', {
          :name        => 'ModelName',
          :table_name  => "table_name",
          :primary_key => "pk",
        })
      end

      let(:instance) { stub }

      let(:orm) { SequelClass.new(model) }

      def fake_dataset(object, stubs = {})
        Array(object).tap do |collection|
          stubs[:all] ||= collection
          collection.stub(stubs)
        end
      end

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
        before  { model.stub(:columns => [:foo, :bar]) }
        subject { orm.column_names }
        it { should == [:foo, :bar] }
      end

      describe ".[](pk)" do
        before  { model.stub(:[]).with('pk').and_return('value') }
        subject { orm['pk'] }
        it { should == 'value' }
      end

      describe ".values_at(*pks)" do
        let(:pks) { [1,2,3] }
        let(:dataset) { fake_dataset("value") }

        before do
          model.stub(:filter).with(:pk => pks).and_return(dataset)
        end

        subject { orm.values_at(*pks) }
        it { should == ['value'] }
      end

      describe ".include?(pk)" do
        let(:dataset) { fake_dataset([]) }

        before  { model.stub(:filter).with(:pk => 'pk').and_return([]) }
        subject { orm.include?('pk') }
        it { should be_false }
      end

      describe ".size" do
        before  { model.stub(:count).and_return('the number of items') }
        subject { orm.size }
        it { should == 'the number of items' }
      end

      describe ".values" do
        let(:page) { stub }
        before do
          AccessControl.stub(:default_batch_size).and_return(1000)
          model.stub(:each_page).with(1000).and_yield(page)
          page.stub(:each).and_yield('all sequel objects')
        end
        subject { orm.values }
        specify { subject.to_a.should == ['all sequel objects'] }
      end

      describe ".new" do
        # This method only need to return an ordinary instance, which must
        # respond to readers and writers corresponding to the column names.  In
        # the case of Sequel this is just a regular instantiation.
        before  { model.stub(:new).and_return(instance) }
        subject { orm.new }
        it { should be instance }
      end

      describe ".subset(subset_name, *args)" do
        # By calling this method the caller expects to get a subset of the
        # whole set of objects, and will want to iterate over it.  Sequel's
        # dataset fit this expectation.  This method should not be abused as a
        # general way to send calls to the underlying ORM class.
        it "just forwards the subset as a dataset or class method call" do
          p1, p2 = stub, stub
          returned_value = stub
          model.stub(:some_dataset).with(p1, p2).and_return(returned_value)
          orm.subset(:some_dataset, p1, p2).should be returned_value
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
        # Since Sequel does exactly that, the implementation simply
        # delegates the call.
        before  { instance.stub(:save).and_return('the answer') }
        subject { orm.persist(instance) }
        it { should == 'the answer' }
      end

      describe ".persisted?(instance)" do
        context "when the instance is a new record" do
          before  { instance.stub(:new?).and_return(true) }
          subject { orm.persisted?(instance) }
          it { should be_false }
        end

        context "when the instance isn't a new record" do
          before  { instance.stub(:new?).and_return(false) }
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
