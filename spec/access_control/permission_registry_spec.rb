require 'spec_helper'
require 'access_control/configuration'
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
        AccessControl.configure do |config|
          config.default_create_permissions = []
          config.default_destroy_permissions = []
          config.default_query_permissions = []
          config.default_update_permissions = []
          config.default_view_permissions = []
        end
      end

      it "registers permissions through self.register" do
        PermissionRegistry.register('some permission')
        PermissionRegistry.all.should include('some permission')
        PermissionRegistry.all.size.should == 1
      end

      it "accepts an argument list of permissions to register" do
        PermissionRegistry.register('some permission', 'another permission')
        PermissionRegistry.all.should include('some permission')
        PermissionRegistry.all.should include('another permission')
        PermissionRegistry.all.size.should == 2
      end

      it "accepts an array of permissions to register" do
        PermissionRegistry.register(['some permission', 'another permission'])
        PermissionRegistry.all.should include('some permission')
        PermissionRegistry.all.should include('another permission')
        PermissionRegistry.all.size.should == 2
      end

      it "accepts a set of permissions to register" do
        PermissionRegistry.register(
          Set.new(['some permission', 'another permission'])
        )
        PermissionRegistry.all.should include('some permission')
        PermissionRegistry.all.should include('another permission')
        PermissionRegistry.all.size.should == 2
      end

      it "loads all controllers when registered permissions are requested" do
        PermissionRegistry.should_receive(:load_all_controllers)
        PermissionRegistry.all
      end

      it "doesn't load controllers if the registry is not cleared" do
        # The before block clears the registry.
        PermissionRegistry.all # makes the loading
        # Now the registry is not cleared, so should not load controllers.
        PermissionRegistry.should_not_receive(:load_all_controllers)
        PermissionRegistry.all
      end

      it "loads all models when registered permissions are requested" do
        PermissionRegistry.should_receive(:load_all_models)
        PermissionRegistry.all
      end

      it "doesn't load models if the registry is not cleared" do
        # The before block clears the registry.
        PermissionRegistry.all # makes the loading
        # Now the registry is not cleared, so should not load models.
        PermissionRegistry.should_not_receive(:load_all_models)
        PermissionRegistry.all
      end

      it "loads all configuration permissions when registered permissions "\
         "are requested" do
        AccessControl.config.should_receive(:register_permissions)
        PermissionRegistry.all
      end

      it "doesn't load configuration permissions if the registry is not "\
         "cleared" do
        # The before block clears the registry.
        PermissionRegistry.all # makes the loading
        # Now the registry is not cleared, so should not load controllers.
        AccessControl.config.should_not_receive(:register_permissions)
        PermissionRegistry.all
      end

      describe "with options" do

        # The options stuff: this never overwrites any option, and should
        # preserve the final result no matter the order the permissions are
        # registered.
        #
        # Permissions registered with exactly the same options will be
        # registered once.  Any different option will generate two or more
        # entries.  Anyway, the result of `all_with_options` is a hash, keyed
        # by the permission name, and the values are enumerables with unique
        # values, and the order should not matter for any purpose (the
        # implementation is allowed to use a Set in this case as the value).

        it "accepts options" do
          PermissionRegistry.register('some permission', :option => 'Value')
        end

        it "registers when using options" do
          PermissionRegistry.register('some permission', :option => 'Value')
          PermissionRegistry.all_with_options['some permission'].
            should include(:option => 'Value')
        end

        it "registers many permissions using the same options" do
          PermissionRegistry.register('some permission', 'another permission',
                                      :option => 'Value')
          r = PermissionRegistry.all_with_options
          r['some permission'].should include(:option => 'Value')
          r['some permission'].size.should == 1
          r['another permission'].should include(:option => 'Value')
          r['another permission'].size.should == 1
          r.size.should == 2
        end

        it "registers a permission with the same options once" do
          PermissionRegistry.register('some permission', :option => 'Value')
          PermissionRegistry.register('some permission', :option => 'Value')
          r = PermissionRegistry.all_with_options
          r['some permission'].should include(:option => 'Value')
          r['some permission'].size.should == 1
          r.size.should == 1
        end

        it "registers a permission with all different options passed" do
          PermissionRegistry.register('some permission', :option => 'Value1',
                                      :other_option => 'Value2')
          PermissionRegistry.register('some permission', :option => 'Value2')
          r = PermissionRegistry.all_with_options
          r['some permission'].should include(:option => 'Value1',
                                              :other_option => 'Value2')
          r['some permission'].should include(:option => 'Value2')
          r['some permission'].size.should == 2
          r.size.should == 1
        end

        it "registers an empty hash if no options are passed" do
          PermissionRegistry.register('some permission')
          PermissionRegistry.all_with_options['some permission'].
            should include({})
          PermissionRegistry.all_with_options['some permission'].size.
            should == 1
          PermissionRegistry.all_with_options.size.should == 1
        end

        it "registers when using options and permission in #all" do
          PermissionRegistry.register('some permission', :option => 'Value')
          PermissionRegistry.all.should include('some permission')
          PermissionRegistry.all.size.should == 1
        end

        it "registers the same permission with different options but #all "\
          "returns the permission only once" do
          PermissionRegistry.register('some permission', :option => 'Value1')
          PermissionRegistry.register('some permission', :option => 'Value2')
          PermissionRegistry.all.should include('some permission')
          PermissionRegistry.all.size.should == 1
        end

        it "loads all controllers when registered with options are "\
           "requested" do
          PermissionRegistry.should_receive(:load_all_controllers)
          PermissionRegistry.all_with_options
        end

        it "doesn't load controllers if the registry is not cleared" do
          # The before block clears the registry.
          PermissionRegistry.all_with_options # makes the loading
          # Now the registry is not cleared, so should not load models.
          PermissionRegistry.should_not_receive(:load_all_controllers)
          PermissionRegistry.all_with_options
        end

        it "loads all models when registered with options are requested" do
          PermissionRegistry.should_receive(:load_all_models)
          PermissionRegistry.all_with_options
        end

        it "doesn't load models if the registry is not cleared" do
          # The before block clears the registry.
          PermissionRegistry.all_with_options # makes the loading
          # Now the registry is not cleared, so should not load models.
          PermissionRegistry.should_not_receive(:load_all_models)
          PermissionRegistry.all_with_options
        end

        it "loads all configuration permissions when registered permissions "\
          "with options are requested" do
          AccessControl.config.should_receive(:register_permissions)
          PermissionRegistry.all_with_options
        end

        it "doesn't load configuration permissions if the registry is not "\
          "cleared" do
          # The before block clears the registry.
          PermissionRegistry.all_with_options # makes the loading
          # Now the registry is not cleared, so should not load controllers.
          AccessControl.config.should_not_receive(:register_permissions)
          PermissionRegistry.all_with_options
        end

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
          PermissionRegistry.all.should include(p)
        end

        it "registers '#{p}' with empty options" do
          PermissionRegistry.all_with_options[p].should include({})
        end

      end

    end

  end
end
