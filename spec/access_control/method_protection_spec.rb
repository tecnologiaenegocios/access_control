require 'spec_helper'
require 'access_control/method_protection'

module AccessControl
  describe MethodProtection do

    let(:manager) { mock('manager') }
    let(:klass) { Class.new { include MethodProtection } }

    before do
      AccessControl.stub(:manager).and_return(manager)
      Registry.stub!(:register)
      manager.stub(:can!)
      klass.stub(:name).and_return('TheClassName')
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
          with('some permission', :metadata => 'value')
        klass.protect(:some_method, :with => 'some permission',
                      :data => { :metadata => 'value'})
      end

      describe "on regular methods" do

        before do
          klass.class_eval do
            protect :some_method, :with => 'some permission'
            def some_method
              'result'
            end
          end
        end

        [:new, :allocate].each do |creation_method|
          it "checks permissions when the method is called "\
             "(using #{creation_method})" do
            instance = klass.send(creation_method)
            manager.should_receive(:can!).
              with(Set.new(['some permission']), instance)
            instance.some_method
          end

          it "returns what the method returns if allowed" do
            manager.stub(:can!)
            klass.send(creation_method).some_method.should == 'result'
          end
        end

      end

      describe "on dynamic methods" do

        let(:new_instance) { klass.new }
        let(:allocated_instance) { klass.allocate }

        before do
          klass.class_eval do
            protect :some_method, :with => 'some permission'
            def method_missing method_name, *args, &block
              'result'
            end
          end
        end

        [:new, :allocate].each do |creation_method|
          it "checks permissions when the method is called "\
             "(using #{creation_method})" do
            instance = klass.send(creation_method)
            manager.should_receive(:can!).
              with(Set.new(['some permission']), instance)
            instance.some_method
          end

          it "returns what the method returns if allowed" do
            manager.stub(:can!)
            klass.send(creation_method).some_method.should == 'result'
          end
        end

      end

    end

  end
end
