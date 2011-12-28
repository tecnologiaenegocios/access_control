require 'spec_helper'
require 'access_control/persistable'

module AccessControl
  describe Persistable do
    let(:model)            { Class.new }
    let(:persistent_model) { stub(:new => persistent, :column_names => []) }
    let(:persistent)       { stub(:new_record? => true) }

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
        undef_method :id
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

    describe "property delegation" do
      before do
        persistent_model.stub(:column_names => ['property'])
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

      method1 = lambda { model.wrap(persistent) }
      method2 = lambda { model.new }

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
        # Implementors can override #persist, which must return true or false.
        #
        # Returning true means OK, whilst false means that the persistent
        # object couldn't be saved at all.
        #
        # However, a default implementation is provided.

        it "delegates to persistent.save" do
          persistent.stub(:save).and_return('the result of saving persistent')
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
          persistent_model.stub(:column_names).and_return(['foo'])
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
          before { persistent.stub(:new_record? => false) }

          it { should be_persisted }
        end

        context "persistent object not saved yet" do
          before { persistent.stub(:new_record? => true) }

          it { should_not be_persisted }
        end
      end

      describe "#destroy" do
        # Implementors can override #destroy, which must at some point call
        # super or destroy the persistent manually.
        #
        # After being destroyed, the instance should not accept modifications,
        # since they can't be persisted.  At this point we rely on ActiveRecord
        # implementation of #destroy, which cares about freezing the instance.

        it "delegates to persistent.destroy" do
          persistent.stub(:destroy).
            and_return('the result of destroying persistent')
          persistable = model.wrap(persistent)
          persistable.destroy.should == 'the result of destroying persistent'
        end
      end

    end

    describe "equality comparison" do
      specify "two persistables are equal if their persistents are equal" do
        p1 = 'a persistent'
        p2 = 'a persistent'

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

    describe "query interface" do
      describe ".all" do
        it "delegates to persistent_model.all and wraps it in a scope" do
          scope         = stub('Regular scope')
          wrapped_scope = stub('Wrapped scope')

          persistent_model.stub(:all).and_return(scope)
          Persistable::WrapperScope.stub(:new).with(model, scope).
            and_return(wrapped_scope)

          model.all.should == wrapped_scope
        end
      end

      describe ".fetch" do
        it "returns the persistable whose persistent has the given id" do
          persistent_model.stub(:find_by_id).with('the id').
            and_return(persistent)
          persistable = model.fetch('the id')
          persistable.persistent.should be persistent
        end

        context "when no persistable is found" do
          let(:inexistent_id) { -1 }

          before do
            persistent_model.stub(:find_by_id).with(inexistent_id).
              and_return(nil)
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
        before do
          persistent_model.stub(:all).
            with(:conditions => {:id => [1,2,3]}).
            and_return(['item1', 'item2', 'item3'])
        end

        it "finds persistents with id included in the list given" do
          persistent_results = model.fetch_all([1,2,3]).map(&:persistent)
          persistent_results.should == ['item1', 'item2', 'item3']
        end

        context "when one or more of the ids aren't found" do
          before do
            persistent_model.stub(:all).
              with(:conditions => {:id => [1,2,3]}).
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
          persistent_model.stub(:exists?).with('the id').and_return(true)
          model.has?('the id').should be_true
        end

        it "returns false if there's no persistent with the id provided" do
          persistent_model.stub(:exists?).with('the id').and_return(false)
          model.has?('the id').should be_false
        end
      end

      describe ".count" do
        it "delegates to persistent_model.count" do
          persistent_model.stub(:count).and_return('the total number of items')
          model.count.should == 'the total number of items'
        end
      end

      describe ".delegate_scope" do
        let(:scope_result) { stub('scope result') }

        it "delegates to persistent model and wraps the result" do
          model.delegate_scope :a_named_scope

          wrapped_scope = stub
          persistent_model.stub(:a_named_scope).and_return(scope_result)
          Persistable::WrapperScope.stub(:new).with(model, scope_result).
            and_return(wrapped_scope)

          model.a_named_scope.should be wrapped_scope
        end

        specify "forwards received arguments when calling delegated scopes" do
          model.delegate_scope :a_named_scope

          wrapped_scope = stub
          persistent_model.should_receive(:a_named_scope).with('arg1', 'arg2').
            and_return(scope_result)
          Persistable::WrapperScope.stub(:new).with(model, scope_result).
            and_return(wrapped_scope)

          model.a_named_scope('arg1', 'arg2')
        end

        it "accepts an argument list of scopes to delegate" do
          model.delegate_scope :a_named_scope, :another_named_scope

          model.should respond_to(:a_named_scope)
          model.should respond_to(:another_named_scope)
        end

        it "has an alias method .delegate_scopes, for better readability" do
          model.delegate_scopes :a_named_scope, :another_named_scope

          model.should respond_to(:a_named_scope)
          model.should respond_to(:another_named_scope)
        end

        it "returns all delegated scopes in .delegated_scopes" do
          model.delegate_scopes :a_named_scope, :another_named_scope
          model.delegate_scope :some_other_named_scope

          model.delegated_scopes.should == [
            :a_named_scope,
            :another_named_scope,
            :some_other_named_scope
          ]
        end
      end
    end
  end
end
