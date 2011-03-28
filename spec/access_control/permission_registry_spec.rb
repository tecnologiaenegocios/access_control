require 'spec_helper'

module AccessControl
  describe PermissionRegistry do

    before do
      PermissionRegistry.clear_registry
    end

    describe "permission registering" do

      before do
        PermissionRegistry.stub!(:load_all_controllers)
        PermissionRegistry.stub!(:load_all_models)
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

      it "loads all controllers when registered permissions are requested" do
        PermissionRegistry.should_receive(:load_all_controllers)
        PermissionRegistry.registered
      end

      it "loads all models when registered permissions are requested" do
        PermissionRegistry.should_receive(:load_all_models)
        PermissionRegistry.registered
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

  end
end
