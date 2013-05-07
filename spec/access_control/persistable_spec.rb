require 'spec_helper'
require 'access_control/persistable'

module AccessControl
  describe Persistable do
    let(:model)            { Class.new }
    let(:persistent)       { stub('persistent instance') }
    let(:persistent_model) do
      m = stub(:new => persistent, :column_names => [])
      m.stub(:persisted?).with(persistent).and_return(false)
      m
    end

    before do
      model.class_eval { include Persistable }
      model.stub(:persistent_model).and_return(persistent_model)
    end

    it "undefines #id if it is defined" do
      model = Class.new do
        def id; end
        include Persistable
      end

      model.instance_methods.map(&:to_sym).should_not include(:id)
    end

    it "doesn't raise exceptions if #id wasn't defined on inclusion" do
      model = Class.new do
        undef_method :id if method_defined?(:id)
      end

      inclusion = lambda do
        model.class_eval { include Persistable }
      end

      inclusion.should_not raise_error
    end

    describe ".wrap" do
      it "creates a persistable whose 'persistent' is the given object" do
        object = stub
        persistable = model.wrap(object)

        persistable.persistent.should be object
      end
    end

    describe "#hash" do
      it "is a delegation to the persistent's #hash" do
        persistent = stub(:hash => 12345)
        subject = model.wrap(persistent)

        subject.hash.should == 12345
      end
    end

    describe "property delegation" do
      before do
        persistent_model.stub(:column_names => [:property])
        meta = (class << persistent; self; end)
        meta.class_eval { attr_accessor :property }
        persistent.instance_eval { @property = 'value' }
      end

      it "delegates #to_param" do
        persistent.stub(:to_param).and_return('parameter')
        model.new.to_param.should == 'parameter'
      end

      context "when calling constructor" do
        it "sets properties in the persistent object" do
          model.new(:property => 'different value')
          persistent.property.should == 'different value'
        end
      end

      method1_desc = "on wrapped objects"
      method2_desc = "on initialized objects"

      method1 = Proc.new { model.wrap(persistent) }
      method2 = Proc.new { model.new }

      [ [method1, method1_desc],
        [method2, method2_desc] ].each do |meth, desc|
        context(desc) do
          let(:persistable, &meth)

          it "delegates readers to all columns" do
            persistable.property.should == 'value'
          end

          it "delegates writers to all columns" do
            persistable.property = 'different value'
            persistent.property.should == 'different value'
          end

          context "when reader with the name of a column is already defined" do
            it "uses the method defined" do
              model.class_eval do
                def property
                  'different value'
                end
              end

              persistable.property.should == 'different value'
            end
          end

          context "when writer with the name of a column is already defined" do
            it "uses the method defined" do
              model.class_eval do
                def property= value
                  persistent.property = value.upcase
                end
              end

              persistable.property = 'different value'
              persistent.property.should == 'DIFFERENT VALUE'
            end
          end
        end
      end
    end

    describe "persistency" do

      describe "#persist" do
        # Implementors can override #persist but must call 'super' and return
        # true or false.
        #
        # Returning true means OK, whilst false means that the persistent
        # object couldn't be saved at all.
        it "delegates to persistent.save" do
          persistent_model.stub(:persist).with(persistent).
            and_return('the result of saving persistent')
          persistable = model.new
          persistable.persist.should == 'the result of saving persistent'
        end
      end

      describe "#persist!" do
        subject { model.new }

        it "returns the instance if #persist returns true" do
          model.class_eval do
            def persist
              true
            end
          end

          subject.persist!.should be subject
        end

        it "raises RecordNotPersisted if #persist returns false" do
          model.class_eval do
            def persist
              false
            end
          end

          lambda{ subject.persist! }.should raise_exception(RecordNotPersisted)
        end
      end

      describe ".store" do
        before do
          persistent_model.stub(:column_names).and_return([:foo])
          persistent.stub(:foo=).with(:bar)
          model.class_eval do
            def persist
              true
            end
          end
        end

        it "should set each property" do
          persistent.should_receive(:foo=).with(:bar)
          model.store(:foo => :bar)
        end

        it "saves the persistent using the implementation of #persist" do
          model.class_eval do
            def persist
              persistent.make_it_persist!
              true
            end
          end
          persistent.should_not_receive(:save)
          persistent.should_receive(:make_it_persist!)
          model.store(:foo => :bar)
        end

        context "when persistent is successfully saved" do
          it "returns a wrapped persistent" do
            persistable = model.store(:foo => :bar)
            persistable.persistent.should be persistent
          end
        end

        context "when persistent fails to be saved" do
          before do
            model.class_eval do
              def persist
                false
              end
            end
          end

          it "raises RecordNotPersisted" do
            lambda {
              model.store(:foo => :bar)
            }.should raise_exception(RecordNotPersisted)
          end
        end
      end

      describe "#persisted?" do
        subject { model.wrap(persistent) }

        context "persistent object already saved" do
          before { persistent_model.stub(:persisted?).
                   with(persistent).and_return(true) }

          it { should be_persisted }
        end

        context "persistent object not saved yet" do
          before { persistent_model.stub(:persisted?).
                   with(persistent).and_return(false) }

          it { should_not be_persisted }
        end
      end

      describe "#destroy" do
        it "delegates to persistent_model.delete(persistent)" do
          persistent_model.should_receive(:delete).with(persistent)
          persistable = model.wrap(persistent)
          persistable.destroy
        end
      end

    end

    describe "equality comparison" do
      specify "two persistables are equal if their persistents are equal" do
        p1 = stub
        p2 = stub

        persistent_model.stub(:instance_eql?).
          with(p1, p2).and_return(true)

        persistable1 = model.wrap(p1)
        persistable2 = model.wrap(p2)

        persistable1.should == persistable2
      end

      specify "a persistable is never equal to an object which is not of the "\
              "same type" do
        persistent = stub

        fake_persistable = stub(:persistent => persistent)
        persistable      = model.wrap(persistent)

        persistable.should_not == fake_persistable
      end
    end

    describe "#eql?" do
      let(:persistent1) { stub("Persistent 1") }
      let(:persistent2) { stub("Persistent 2") }

      subject     { model.wrap(persistent1) }
      let(:other) { model.wrap(persistent2) }

      it "is true if the persistents are eql" do
        persistent1.stub(:eql?).with(persistent2).and_return(true)
        subject.should be_eql(other)
      end

      it "is false if the persistents aren't eql" do
        persistent1.stub(:eql?).with(persistent2).and_return(false)
        subject.should_not be_eql(other)
      end

      it "is always false if the other object isn't from the same class" do
        persistent1.stub(:eql?).with(persistent2).and_return(true)
        fake_persistable = stub(:persistent => persistent2)

        subject.should_not be_eql(fake_persistable)
      end
    end

    describe "query interface" do
      describe ".all" do
        it "delegates to persistent_model.values and wraps it in a subset" do
          subset         = stub('Regular subset')
          wrapped_subset = stub('Wrapped subset')

          persistent_model.stub(:values).and_return(subset)
          Persistable::WrappedSubset.stub(:new).with(model, subset).
            and_return(wrapped_subset)

          model.all.should == wrapped_subset
        end
      end

      describe ".fetch" do
        it "returns the persistable whose persistent has the given id" do
          persistent_model.stub(:[]).with('the id').and_return(persistent)
          persistable = model.fetch('the id')
          persistable.persistent.should be persistent
        end

        context "when no persistable is found" do
          let(:inexistent_id) { -1 }

          before do
            persistent_model.stub(:[]).with(inexistent_id).and_return(nil)
          end

          context "and no block is given" do
            it "raises AccessControl::NotFoundError if no default is given" do
              lambda {
                model.fetch(inexistent_id)
              }.should raise_exception(AccessControl::NotFoundError)
            end

            it "returns the default if given" do
              default = stub
              model.fetch(inexistent_id, default).should be default
            end
          end

          context "and a block is given" do
            it "uses the block if no default is given " do
              default = stub
              returned_value = model.fetch(inexistent_id) { default }
              returned_value.should be default
            end

            it "uses the block even if a default is given" do
              value_default = stub('as formal argument')
              block_default = stub('from block result')
              returned_value = model.fetch(inexistent_id, value_default) do
                block_default
              end
              returned_value.should be block_default
            end
          end
        end
      end

      describe ".fetch_all" do
        it "finds persistents with pk included in the list given" do
          persistent_model.stub(:values_at).
            with(1,2,3).and_return(['item1', 'item2', 'item3'])
          persistent_results = model.fetch_all([1,2,3]).map(&:persistent)
          persistent_results.should == ['item1', 'item2', 'item3']
        end

        it "works with a set" do
          persistent_model.stub(:values_at).with(1).and_return(['item1'])
          persistent_results = model.fetch_all(Set[1]).map(&:persistent)
          persistent_results.should == ['item1']
        end

        context "when one or more of the ids aren't found" do
          before do
            persistent_model.stub(:values_at).with(1,2,3).
              and_return(['item1', 'item3'])
          end

          it "raises AccessControl::NotFoundError" do
            lambda {
              model.fetch_all([1,2,3])
            }.should raise_exception(AccessControl::NotFoundError)
          end
        end
      end

      describe ".has?" do
        it "returns true if there's a persistent with the id provided" do
          persistent_model.stub(:include?).with('the id').and_return(true)
          model.has?('the id').should be_true
        end

        it "returns false if there's no persistent with the id provided" do
          persistent_model.stub(:include?).with('the id').and_return(false)
          model.has?('the id').should be_false
        end
      end

      describe ".count" do
        it "delegates to persistent_model.count" do
          persistent_model.stub(:size).and_return('the total number of items')
          model.count.should == 'the total number of items'
        end
      end

      describe ".delegate_subset" do
        let(:subset) { stub('subset') }

        it "delegates to persistent model and wraps the result" do
          model.delegate_subset :a_named_subset

          wrapped_subset = stub
          persistent_model.stub(:subset).with(:a_named_subset).
            and_return(subset)
          Persistable::WrappedSubset.stub(:new).with(model, subset).
            and_return(wrapped_subset)

          model.a_named_subset.should be wrapped_subset
        end

        specify "forwards received arguments when calling delegated subsets" do
          model.delegate_subset :a_named_subset

          wrapped_subset = stub
          persistent_model.stub(:subset).with(:a_named_subset, 'arg1', 'arg2').
            and_return(subset)
          Persistable::WrappedSubset.stub(:new).with(model, subset).
            and_return(wrapped_subset)

          model.a_named_subset('arg1', 'arg2').should be wrapped_subset
        end

        it "when receives a block, uses it to preprocess the arguments" do
          model.delegate_subset :a_named_subset do |*args|
            args.reverse
          end

          wrapped_subset = stub
          persistent_model.stub(:subset).with(:a_named_subset, 'arg2', 'arg1').
            and_return(subset)
          Persistable::WrappedSubset.stub(:new).with(model, subset).
            and_return(wrapped_subset)

          model.a_named_subset('arg1', 'arg2').should be wrapped_subset
        end

        describe ".delegate_subsets" do
          it "delegates multiple subsets at once" do
            model.delegate_subsets :a_named_subset, :another_named_subset

            model.should respond_to(:a_named_subset)
            model.should respond_to(:another_named_subset)
          end
        end

        describe ".delegated_subsets" do
          it "returns all delegated subsets" do
            model.delegate_subsets :a_named_subset, :another_named_subset
            model.delegate_subset :some_other_named_subset

            model.delegated_subsets.should include_only(:a_named_subset,
              :another_named_subset, :some_other_named_subset)
          end

          it "when given a block, uses it as a preprocessor for all subsets" do
            model.delegate_subsets :subset1, :subset2 do |*args|
              args.reverse
            end

            wrapped_subset = stub
            persistent_model.stub(:subset).with(:subset1, 'arg2', 'arg1').
              and_return(subset)
            persistent_model.stub(:subset).with(:subset2, 'arg2', 'arg1').
              and_return(subset)

            Persistable::WrappedSubset.stub(:new).with(model, subset).
              and_return(wrapped_subset)

            model.subset1('arg1', 'arg2').should be wrapped_subset
            model.subset2('arg1', 'arg2').should be wrapped_subset
          end
        end
      end
    end
  end
end
