require 'spec_helper'
require 'access_control/permission_registry'

module AccessControl
  describe PermissionRegistry do

    before do
      PermissionRegistry.clear_registry
    end

    describe "permission registering" do

      before do
        PermissionRegistry.stub!(:load_all_controllers)
        PermissionRegistry.stub!(:load_all_models)
        PermissionRegistry.stub!(:register_undeclared_permissions)
      end

      it "registers permissions through self.register" do
        PermissionRegistry.register('some permission')
        PermissionRegistry.registered.should include('some permission')
        PermissionRegistry.registered.size.should == 1
      end

      it "accepts an argument list of permissions to register" do
        PermissionRegistry.register('some permission', 'another permission')
        PermissionRegistry.registered.should include('some permission')
        PermissionRegistry.registered.should include('another permission')
        PermissionRegistry.registered.size.should == 2
      end

      it "accepts an array of permissions to register" do
        PermissionRegistry.register(['some permission', 'another permission'])
        PermissionRegistry.registered.should include('some permission')
        PermissionRegistry.registered.should include('another permission')
        PermissionRegistry.registered.size.should == 2
      end

      it "accepts a set of permissions to register" do
        PermissionRegistry.register(
          Set.new(['some permission', 'another permission'])
        )
        PermissionRegistry.registered.should include('some permission')
        PermissionRegistry.registered.should include('another permission')
        PermissionRegistry.registered.size.should == 2
      end

      it "accepts options" do
        PermissionRegistry.register('some permission', :option => 'Value')
      end

      it "registers when using options" do
        PermissionRegistry.register('some permission', :option => 'Value')
        PermissionRegistry.registered_with_options.should include(
          ['some permission', {:option => 'Value'}]
        )
        PermissionRegistry.registered_with_options.size.should == 1
      end

      it "registers many permissions using the same options" do
        PermissionRegistry.register('some permission', 'another permission',
                                    :option => 'Value')
        PermissionRegistry.registered_with_options.should include(
          ['some permission', {:option => 'Value'}]
        )
        PermissionRegistry.registered_with_options.should include(
          ['another permission', {:option => 'Value'}]
        )
        PermissionRegistry.registered_with_options.size.should == 2
      end

      it "registers when using options and permission in #registered" do
        PermissionRegistry.register('some permission', :option => 'Value')
        PermissionRegistry.registered.should include('some permission')
        PermissionRegistry.registered.size.should == 1
      end

      it "registers an empty hash if no options are passed" do
        PermissionRegistry.register('some permission')
        PermissionRegistry.registered_with_options.should include(
          ['some permission', {}]
        )
        PermissionRegistry.registered_with_options.size.should == 1
      end

      it "loads all controllers when registered permissions are requested" do
        PermissionRegistry.should_receive(:load_all_controllers)
        PermissionRegistry.registered
      end

      it "loads all models when registered permissions are requested" do
        PermissionRegistry.should_receive(:load_all_models)
        PermissionRegistry.registered
      end

      it "loads all controllers when registered with options are requested" do
        PermissionRegistry.should_receive(:load_all_controllers)
        PermissionRegistry.registered_with_options
      end

      it "loads all models when registered with options are requested" do
        PermissionRegistry.should_receive(:load_all_models)
        PermissionRegistry.registered_with_options
      end

    end

    describe "controller loading" do

      # The method specified here loads the controllers in the hope that they
      # will make calls to `protect` once loaded, which in turn makes the
      # registering of permissions.

      it "can load all controllers though Dir[]" do
        Dir.should_receive(:[]).
          with(Rails.root + 'app/controllers/**/*.rb').and_return([])
        PermissionRegistry.load_all_controllers
      end

      it "gets a top level constant based on each filename" do
        Dir.stub!(:[]).and_return(['some_controller.rb',
                                   'another_controller.rb'])
        ActiveSupport::Inflector.should_receive(:constantize).
          with('SomeController')
        ActiveSupport::Inflector.should_receive(:constantize).
          with('AnotherController')
        PermissionRegistry.load_all_controllers
      end

    end

    describe "model loading" do

      # The method specified here loads the models in the hope that they will
      # make calls to `protect` once loaded, which in turn makes the
      # registering of permissions.

      it "can load all controllers though Dir[]" do
        Dir.should_receive(:[]).
          with(Rails.root + 'app/models/**/*.rb').and_return([])
        PermissionRegistry.load_all_models
      end

      it "gets a top level constant based on each filename" do
        Dir.stub!(:[]).and_return(['some_model.rb',
                                   'another_model.rb'])
        ActiveSupport::Inflector.should_receive(:constantize).
          with('SomeModel')
        ActiveSupport::Inflector.should_receive(:constantize).
          with('AnotherModel')
        PermissionRegistry.load_all_models
      end

    end

    describe "undeclared permissions" do

      before do
        PermissionRegistry.stub!(:load_all_controllers)
        PermissionRegistry.stub!(:load_all_models)
      end

      %w(grant_roles share_own_roles change_inheritance_blocking).each do |p|

        it "registers '#{p}'" do
          PermissionRegistry.registered.should include(p)
        end

        it "registers '#{p}' with empty options" do
          PermissionRegistry.registered_with_options.should include([p, {}])
        end

      end

    end

  end
end
