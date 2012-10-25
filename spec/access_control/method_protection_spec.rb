require 'spec_helper'
require 'access_control/method_protection'

# TODO Merge this with ControllerSecurity.protect.  Their API's work (almost)
# the same.

module AccessControl
  describe MethodProtection do
    let(:manager)     { mock('manager') }
    let(:registry)    { stub }

    def set_class
      Object.const_set('TheClass', Class.new{ include MethodProtection })
    end

    def unset_class
      Object.send(:remove_const, 'TheClass')
    end

    def klass
      TheClass
    end

    def registry
      AccessControl.registry
    end

    before do
      set_class
      AccessControl.stub(:manager).and_return(manager)
      manager.stub(:can!)
    end

    after do
      unset_class
      registry.clear
    end

    describe ".protect" do
      it "stores permission in the Registry" do
        klass.protect(:some_method, :with => 'some permission')
        registry.fetch('some permission').name.should == 'some permission'
      end

      it "adds class and method to the ac_methods property of the permission" do
        klass.protect(:some_method, :with => 'some permission')

        registry.fetch('some permission').ac_methods.
          should include_only(['TheClass', :some_method])
      end

      it "adds class to the ac_classes property of the permission" do
        klass.protect(:some_method, :with => 'some permission')

        registry.fetch('some permission').ac_classes.
          should include_only('TheClass')
      end

      it "combines permissions in different declarations for same method" do
        klass.protect(:some_method, :with => 'some permission')
        klass.protect(:some_method, :with => 'some other permission')

        registry.fetch('some permission').ac_methods.
          should include_only(['TheClass', :some_method])
        registry.fetch('some other permission').ac_methods.
          should include_only(['TheClass', :some_method])
      end

      it "combines methods in different declarations for same permission" do
        klass.protect(:some_method, :with => 'some permission')
        klass.protect(:some_other_method, :with => 'some permission')

        registry.fetch('some permission').ac_methods.
          should include_only(['TheClass', :some_method],
                              ['TheClass', :some_other_method])
      end

      context "when a block is given" do
        it "runs the block with the permission being indexed" do
          permission = nil
          klass.protect(:some_method, :with => 'some permission') do |p|
            permission = p
          end

          registry.fetch('some permission').should equal permission
        end
      end

      describe "regular and dynamic methods" do
        def set_methods
          klass.class_eval do
            def regular_method(*args, &block)
              [:regular_method, args.first, block]
            end
            def setter_method=(*args, &block)
              [:setter_method=, args.first, block]
            end
            def predicate_method?(*args, &block)
              [:predicate_method?, args.first, block]
            end
            def method_missing method_name, *args, &block
              self.class.class_eval do
                define_method(method_name) do |*other_args, &other_block|
                  [method_name, other_args.first, other_block]
                end
              end
              send(method_name, *args, &block)
            end
          end
        end

        before do
          set_methods
          klass.class_eval do
            protect :regular_method,    :with => 'some permission'
            protect :setter_method=,    :with => 'some permission'
            protect :predicate_method?, :with => 'some permission'
            protect :dynamic_method,    :with => 'some permission'
          end
        end

        def permission
          registry.fetch('some permission')
        end

        [:new, :allocate].each do |creation_method|
          [ :regular_method, :dynamic_method,
            :setter_method=, :predicate_method?].each do |meth|
            describe "using .#{creation_method}" do
              describe "calling ##{meth}" do
                def proc_as_block_for_methods
                  @proc_as_block_for_methods ||= Proc.new { }
                end

                def calling_method(instance, meth)
                  instance.send(meth, 1, &proc_as_block_for_methods)
                end

                def expected_result(meth)
                  [meth, 1, proc_as_block_for_methods]
                end

                it "checks permissions when the method is called " do
                  instance = klass.send(creation_method)
                  manager.should_receive(:can!).
                    with(collection(permission), instance)
                  calling_method(instance, meth)
                end

                it "checks permissions even if class is reloaded" do
                  unset_class
                  set_class
                  set_methods
                  instance = klass.send(creation_method)
                  manager.should_receive(:can!).
                    with(collection(permission), instance)
                  calling_method(instance, meth)
                end

                it "checks permission even after the first call" do
                  instance = klass.send(creation_method)
                  calling_method(instance, meth)
                  another_instance = klass.send(creation_method)
                  manager.should_receive(:can!).
                    with(collection(permission), another_instance)
                  calling_method(another_instance, meth)
                end

                it "returns what the method returns if allowed" do
                  manager.stub(:can!)
                  instance = klass.send(creation_method)
                  calling_method(instance, meth).should == expected_result(meth)
                end
              end
            end
          end
        end
      end

      describe "initialization" do
        before do
          klass.class_eval do
            protect :value=, :with => 'some permission'
            def initialize(value)
              self.value = value
            end
            def value= value
              @value = value
            end
            def value
              @value
            end
          end
        end

        def permission
          registry.fetch('some permission')
        end

        context "when the user has no permission" do
          before do
            manager.stub(:can!).
              with(collection(permission), instance_of(klass)).
              and_raise(StandardError)
          end

          it "setups protection before initialization" do
            lambda { klass.new('foo') }.should raise_error
          end
        end

        context "when the user has permission" do
          it "performs checking even during initialization" do
            manager.should_receive(:can!).
              with(collection(permission), instance_of(klass))
            lambda { klass.new('foo') }.should_not raise_error
          end

          it "performs the call" do
            klass.new('foo').value.should == 'foo'
          end
        end
      end
    end
  end
end
