require 'spec_helper'
require 'access_control/configuration'
require 'access_control/registry'

module AccessControl
  describe Registry do

    before do
      Registry.clear_registry
    end

    describe "permission registering" do

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

      end

    end

    describe "#load_all_controllers" do

      # The method specified here loads the controllers in the hope that they
      # will make calls to `protect` once loaded, which in turn makes the
      # registering of permissions.

      it "can load all controllers though Dir[]" do
        Dir.should_receive(:[]).
          with(Rails.root + 'app/controllers/**/*.rb').and_return([])
        Registry.load_all_controllers
      end

      it "gets a top level constant based on each filename" do
        Dir.stub(:[]).and_return(['some_controller.rb',
                                  'another_controller.rb'])
        ActiveSupport::Inflector.should_receive(:constantize).
          with('SomeController')
        ActiveSupport::Inflector.should_receive(:constantize).
          with('AnotherController')
        Registry.load_all_controllers
      end

    end

    describe "#load_all_models" do

      # The method specified here loads the models in the hope that they will
      # make calls to `protect` once loaded, which in turn makes the
      # registering of permissions.

      it "can load all controllers though Dir[]" do
        Dir.should_receive(:[]).
          with(Rails.root + 'app/models/**/*.rb').and_return([])
        Registry.load_all_models
      end

      it "gets a top level constant based on each filename" do
        Dir.stub(:[]).and_return(['some_model.rb',
                                  'another_model.rb'])
        ActiveSupport::Inflector.should_receive(:constantize).
          with('SomeModel')
        ActiveSupport::Inflector.should_receive(:constantize).
          with('AnotherModel')
        Registry.load_all_models
      end

    end

    describe "#load_all_permissions_from_config" do
      it "defers the job to the config object" do
        AccessControl.config.should_receive(:register_permissions)
        Registry.load_all_permissions_from_config
      end
    end

    describe "#register_undeclared_permissions" do

      %w(grant_roles share_own_roles change_inheritance_blocking).each do |p|

        it "registers '#{p}'" do
          Registry.register_undeclared_permissions
          Registry.all.should include(p)
        end

        it "registers '#{p}' with empty options" do
          Registry.register_undeclared_permissions
          Registry.all_with_options[p].should include({})
        end

      end

    end

  end
end
