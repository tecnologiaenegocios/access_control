require 'spec_helper'
require 'access_control/method_protection'

# TODO Merge this with ControllerSecurity.protect.  Their API's work (almost)
# the same.

module AccessControl
  describe MethodProtection do

    let(:manager) { mock('manager') }

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
    end

    after do
      unset_class
      Registry.clear_registry
    end

    describe ".protect" do

      it "declares that methods are protected" do
        klass.protect(:some_method, :with => 'some permission')
        klass.protect(:another_method, :with => 'another permission')
        klass.permissions_for(:some_method).
          should == Set.new(['some permission'])
        klass.permissions_for(:another_method).
          should == Set.new(['another permission'])
      end

      it "combines permissions in different declarations for same method" do
        klass.protect(:some_method, :with => 'some permission')
        klass.protect(:some_method, :with => 'some other permission')
        klass.permissions_for(:some_method).
          should == Set.new(['some permission', 'some other permission'])
      end

      it "accepts an array of permissions" do
        klass.protect(:some_method, :with => ['some permission', 'some other'])
        klass.permissions_for(:some_method).
          should == Set.new(['some permission', 'some other'])
      end

      it "registers permissions with metadata provided" do
        Registry.should_receive(:register).
          with('some permission', hash_including(:metadata => 'value'))
        klass.protect(:some_method, :with => 'some permission',
                      :data => { :metadata => 'value'})
      end

      describe "regular and dynamic methods" do

        def set_methods
          klass.class_eval do
            def regular_method
              'result'
            end
            def method_missing method_name, *args, &block
              'result'
            end
          end
        end

        before do
          set_methods
          klass.class_eval do
            protect :regular_method, :with => 'some permission'
            protect :dynamic_method, :with => 'some permission'
          end
        end

        [:new, :allocate].each do |creation_method|
          [:regular_method, :dynamic_method].each do |meth|
            describe "using .#{creation_method}" do
              describe "calling ##{meth}" do

                it "checks permissions when the method is called " do
                  instance = klass.send(creation_method)
                  manager.should_receive(:can!).
                    with(Set.new(['some permission']), instance)
                  instance.send(meth)
                end

                it "checks permissions even if class is reloaded" do
                  unset_class
                  set_class
                  set_methods
                  instance = klass.send(creation_method)
                  manager.should_receive(:can!).
                    with(Set.new(['some permission']), instance)
                  instance.send(meth)
                end

                it "returns what the method returns if allowed" do
                  manager.stub(:can!)
                  klass.send(creation_method).send(meth).should == 'result'
                end

              end
            end
          end
        end

      end

    end

  end
end
