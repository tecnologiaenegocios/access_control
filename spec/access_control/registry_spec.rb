require 'spec_helper'
require 'access_control/configuration'
require 'access_control/registry'

module AccessControl
  describe Registry do

    before do
      Registry.clear_registry
    end

    describe "permission registering" do

      before do
        Registry.stub!(:load_all_controllers)
        Registry.stub!(:load_all_models)
        Registry.stub!(:register_undeclared_permissions)
        AccessControl.configure do |config|
          config.default_create_permissions = []
          config.default_destroy_permissions = []
          config.default_query_permissions = []
          config.default_update_permissions = []
          config.default_view_permissions = []
        end
      end

      it "registers permissions through self.register" do
        Registry.register('some permission')
        Registry.all.should include('some permission')
        Registry.all.size.should == 1
      end

      it "accepts an argument list of permissions to register" do
        Registry.register('some permission', 'another permission')
        Registry.all.should include('some permission')
        Registry.all.should include('another permission')
        Registry.all.size.should == 2
      end

      it "accepts an array of permissions to register" do
        Registry.register(['some permission', 'another permission'])
        Registry.all.should include('some permission')
        Registry.all.should include('another permission')
        Registry.all.size.should == 2
      end

      it "accepts a set of permissions to register" do
        Registry.register(
          Set.new(['some permission', 'another permission'])
        )
        Registry.all.should include('some permission')
        Registry.all.should include('another permission')
        Registry.all.size.should == 2
      end

      it "loads all controllers when registered permissions are requested" do
        Registry.should_receive(:load_all_controllers)
        Registry.all
      end

      it "doesn't load controllers if the registry is not cleared" do
        # The before block clears the registry.
        Registry.all # makes the loading
        # Now the registry is not cleared, so should not load controllers.
        Registry.should_not_receive(:load_all_controllers)
        Registry.all
      end

      it "loads all models when registered permissions are requested" do
        Registry.should_receive(:load_all_models)
        Registry.all
      end

      it "doesn't load models if the registry is not cleared" do
        # The before block clears the registry.
        Registry.all # makes the loading
        # Now the registry is not cleared, so should not load models.
        Registry.should_not_receive(:load_all_models)
        Registry.all
      end

      it "loads all configuration permissions when registered permissions "\
         "are requested" do
        AccessControl.config.should_receive(:register_permissions)
        Registry.all
      end

      it "doesn't load configuration permissions if the registry is not "\
         "cleared" do
        # The before block clears the registry.
        Registry.all # makes the loading
        # Now the registry is not cleared, so should not load controllers.
        AccessControl.config.should_not_receive(:register_permissions)
        Registry.all
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
          Registry.register('some permission', :option => 'Value')
        end

        it "registers when using options" do
          Registry.register('some permission', :option => 'Value')
          Registry.all_with_options['some permission'].
            should include(:option => 'Value')
        end

        it "registers many permissions using the same options" do
          Registry.register('some permission', 'another permission',
                            :option => 'Value')
          r = Registry.all_with_options
          r['some permission'].should include(:option => 'Value')
          r['some permission'].size.should == 1
          r['another permission'].should include(:option => 'Value')
          r['another permission'].size.should == 1
          r.size.should == 2
        end

        it "registers a permission with the same options once" do
          Registry.register('some permission', :option => 'Value')
          Registry.register('some permission', :option => 'Value')
          r = Registry.all_with_options
          r['some permission'].should include(:option => 'Value')
          r['some permission'].size.should == 1
          r.size.should == 1
        end

        it "registers a permission with all different options passed" do
          Registry.register('some permission', :option => 'Value1',
                            :other_option => 'Value2')
          Registry.register('some permission', :option => 'Value2')
          r = Registry.all_with_options
          r['some permission'].should include(:option => 'Value1',
                                              :other_option => 'Value2')
          r['some permission'].should include(:option => 'Value2')
          r['some permission'].size.should == 2
          r.size.should == 1
        end

        it "registers an empty hash if no options are passed" do
          Registry.register('some permission')
          Registry.all_with_options['some permission'].should include({})
          Registry.all_with_options['some permission'].size.should == 1
          Registry.all_with_options.size.should == 1
        end

        it "registers when using options and permission in #all" do
          Registry.register('some permission', :option => 'Value')
          Registry.all.should include('some permission')
          Registry.all.size.should == 1
        end

        it "registers the same permission with different options but #all "\
          "returns the permission only once" do
          Registry.register('some permission', :option => 'Value1')
          Registry.register('some permission', :option => 'Value2')
          Registry.all.should include('some permission')
          Registry.all.size.should == 1
        end

        it "loads all controllers when registered with options are "\
           "requested" do
          Registry.should_receive(:load_all_controllers)
          Registry.all_with_options
        end

        it "doesn't load controllers if the registry is not cleared" do
          # The before block clears the registry.
          Registry.all_with_options # makes the loading
          # Now the registry is not cleared, so should not load models.
          Registry.should_not_receive(:load_all_controllers)
          Registry.all_with_options
        end

        it "loads all models when registered with options are requested" do
          Registry.should_receive(:load_all_models)
          Registry.all_with_options
        end

        it "doesn't load models if the registry is not cleared" do
          # The before block clears the registry.
          Registry.all_with_options # makes the loading
          # Now the registry is not cleared, so should not load models.
          Registry.should_not_receive(:load_all_models)
          Registry.all_with_options
        end

        it "loads all configuration permissions when registered permissions "\
          "with options are requested" do
          AccessControl.config.should_receive(:register_permissions)
          Registry.all_with_options
        end

        it "doesn't load configuration permissions if the registry is not "\
          "cleared" do
          # The before block clears the registry.
          Registry.all_with_options # makes the loading
          # Now the registry is not cleared, so should not load controllers.
          AccessControl.config.should_not_receive(:register_permissions)
          Registry.all_with_options
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
        Registry.load_all_controllers
      end

      it "gets a top level constant based on each filename" do
        Dir.stub!(:[]).and_return(['some_controller.rb',
                                   'another_controller.rb'])
        ActiveSupport::Inflector.should_receive(:constantize).
          with('SomeController')
        ActiveSupport::Inflector.should_receive(:constantize).
          with('AnotherController')
        Registry.load_all_controllers
      end

    end

    describe "model loading" do

      # The method specified here loads the models in the hope that they will
      # make calls to `protect` once loaded, which in turn makes the
      # registering of permissions.

      it "can load all controllers though Dir[]" do
        Dir.should_receive(:[]).
          with(Rails.root + 'app/models/**/*.rb').and_return([])
        Registry.load_all_models
      end

      it "gets a top level constant based on each filename" do
        Dir.stub!(:[]).and_return(['some_model.rb',
                                   'another_model.rb'])
        ActiveSupport::Inflector.should_receive(:constantize).
          with('SomeModel')
        ActiveSupport::Inflector.should_receive(:constantize).
          with('AnotherModel')
        Registry.load_all_models
      end

    end

    describe "undeclared permissions" do

      before do
        Registry.stub!(:load_all_controllers)
        Registry.stub!(:load_all_models)
      end

      %w(grant_roles share_own_roles change_inheritance_blocking).each do |p|

        it "registers '#{p}'" do
          Registry.all.should include(p)
        end

        it "registers '#{p}' with empty options" do
          Registry.all_with_options[p].should include({})
        end

      end

    end

  end
end
