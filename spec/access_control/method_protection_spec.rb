require 'spec_helper'
require 'access_control/method_protection'

# TODO Merge this with ControllerSecurity.protect.  Their API's work (almost)
# the same.

module AccessControl
  describe MethodProtection do

    let(:manager)     { mock('manager') }
    let(:registry)    { stub }
    let(:permissions) { {} }

    def set_class
      Object.const_set('TheClass', Class.new{ include MethodProtection })
    end

    def unset_class
      Object.send(:remove_const, 'TheClass')
    end

    def klass
      TheClass
    end

    before do
      set_class
      AccessControl.stub(:manager).and_return(manager)
      manager.stub(:can!)

      @old_registry = AccessControl::Registry
      Kernel.silence_warnings { AccessControl.const_set(:Registry, registry) }

      registry.stub(:permissions).and_return(permissions)
      registry.define_singleton_method(:store) do |permission_name, &block|
        permissions[permission_name] ||= OpenStruct.new(
          :name => permission_name,
          :ac_methods => Set.new,
          :ac_classes => Set.new
        )
        block.call(permissions[permission_name])
      end
    end

    after do
      unset_class

      Kernel.silence_warnings do
        AccessControl.const_set(:Registry, @old_registry)
      end
    end

    describe ".protect" do

      it "stores permission in the Registry" do
        Registry.should_receive(:store).with('some permission')
        klass.protect(:some_method, :with => 'some permission')
      end

      it "adds class and method to the ac_methods property of the permission" do
        klass.protect(:some_method, :with => 'some permission')

        permissions['some permission'].ac_methods.
          should include_only(['TheClass', :some_method])
      end

      it "adds class to the ac_classes property of the permission" do
        klass.protect(:some_method, :with => 'some permission')

        permissions['some permission'].ac_classes.
          should include_only('TheClass')
      end

      it "combines permissions in different declarations for same method" do
        klass.protect(:some_method, :with => 'some permission')
        klass.protect(:some_method, :with => 'some other permission')

        permissions['some permission'].ac_methods.
          should include_only(['TheClass', :some_method])
        permissions['some other permission'].ac_methods.
          should include_only(['TheClass', :some_method])
      end

      it "combines methods in different declarations for same permission" do
        klass.protect(:some_method, :with => 'some permission')
        klass.protect(:some_other_method, :with => 'some permission')

        permissions['some permission'].ac_methods.
          should include_only(['TheClass', :some_method],
                              ['TheClass', :some_other_method])
      end

      context "when a block is given" do
        it "runs the block with the permission being indexed" do
          klass.protect(:some_method, :with => 'some permission') do |p|
            p.attribute = 'value'
          end

          permissions['some permission'].attribute.should == 'value'
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

          permission = stub(:name => 'some permission',
                            :ac_methods => Set[
                              ['TheClass', :regular_method],
                              ['TheClass', :setter_method=],
                              ['TheClass', :predicate_method?],
                              ['TheClass', :dynamic_method]
                            ],
                            :ac_classes => Set['TheClass'])

          Registry.stub(:query).
            with(:ac_methods => [['TheClass', :regular_method]]).
            and_return(Set[permission])

          Registry.stub(:query).
            with(:ac_methods => [['TheClass', :setter_method=]]).
            and_return(Set[permission])

          Registry.stub(:query).
            with(:ac_methods => [['TheClass', :predicate_method?]]).
            and_return(Set[permission])

          Registry.stub(:query).
            with(:ac_methods => [['TheClass', :dynamic_method]]).
            and_return(Set[permission])

          Registry.stub(:query).
            with(:ac_classes => ['TheClass']).
            and_return(Set[permission])
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
                  manager.should_receive(:can!).with(['some permission'],
                                                     instance)
                  calling_method(instance, meth)
                end

                it "checks permissions even if class is reloaded" do
                  unset_class
                  set_class
                  set_methods
                  instance = klass.send(creation_method)
                  manager.should_receive(:can!).with(['some permission'],
                                                     instance)
                  calling_method(instance, meth)
                end

                it "checks permission even after the first call" do
                  instance = klass.send(creation_method)
                  calling_method(instance, meth)
                  another_instance = klass.send(creation_method)
                  manager.should_receive(:can!).with(['some permission'],
                                                     another_instance)
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

    end

  end
end
