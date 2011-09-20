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
        Registry.all.should == Set.new(['some permission'])
      end

      it "accepts an argument list of permissions to register" do
        Registry.register('some permission', 'another permission')
        Registry.all.should == Set.new(['some permission',
                                        'another permission'])
      end

      it "accepts an array of permissions to register" do
        Registry.register(['some permission', 'another permission'])
        Registry.all.should == Set.new(['some permission',
                                        'another permission'])
      end

      it "accepts a set of permissions to register" do
        Registry.register(
          Set.new(['some permission', 'another permission'])
        )
        Registry.all.should == Set.new(['some permission',
                                        'another permission'])
      end

      it "registers permissioms only once" do
        Registry.register('some permission')
        Registry.register('some permission')
        Registry.all.should == Set.new(['some permission'])
      end

      describe "with metadata" do

        # Metadata are a way to assign information into a permission when it
        # gets registered.  This allows one to query permissions later
        # according to the data that was registered with them.
        #
        # Suppose that one wants to register a permission for a method in a
        # specific class (say, a field in a model).  One way to do this and
        # still keep track of the registration is by assigning a metadata for
        # the permission.  Example:
        #
        #   Registry.register('read_field_name_in_my_model',
        #                     :model => MyModel.name,
        #                     :method => :field_name)
        #
        # Later the permission could be queried by { :model => MyModel.name,
        # :method => :field_name }.  The metadata is the Hash passed as the
        # last argument to .register.  Note that a metadata cannot hold model
        # classes directly (although most classes can be held) because of the
        # caching/discarding that ActiveSupport::Dependencies does, and so the
        # name of the class is used (both when registering and when querying).
        #
        # A metadata key/value pair never overwrites another:
        #
        #   Register.register('a_permission', :key => 'value')
        #   Register.register('a_permission', :key => 'other_value')
        #
        # The above registrations result in two different metadata for the same
        # permission.  This permission can be queryied with any of the
        # following:
        #
        #   { :key => 'value' }
        #   { :key => 'other_value' }
        #
        # This example group is concerned only with the .register method when
        # using a hash for registering, and the assertions are done inspecting
        # the return of .all_with_metadata and .all.

        it "accepts metadata (an options hash)" do
          Registry.register('some permission', :key => 'value')
        end

        it "registers when using metadata" do
          Registry.register('some permission', :key => 'value')
          Registry.all_with_metadata.should == {
            'some permission' => Set.new([{:key => 'value'}])
          }
        end

        it "registers many permissions using the same metadata" do
          Registry.register('permission 1',
                            'permission 2',
                            :key => 'value')
          Registry.all_with_metadata.should == {
            'permission 1' => Set.new([{:key => 'value'}]),
            'permission 2' => Set.new([{:key => 'value'}])
          }
        end

        it "registers a permission with the same metadata once" do
          Registry.register('some permission', :key => 'value')
          Registry.register('some permission', :key => 'value')
          r = Registry.all_with_metadata
          r.should == { 'some permission' => Set.new([{:key => 'value'}]) }
        end

        it "registers a permission with all different metadata passed" do
          Registry.register('some permission',
                            :key_1 => 'value 1',
                            :key_2 => 'value 2')
          Registry.register('some permission', :key_1 => 'value 2')
          Registry.all_with_metadata.should == {
            'some permission' => Set.new([
              {:key_1 => 'value 1', :key_2 => 'value 2'},
              {:key_1 => 'value 2'}
            ])
          }
        end

        it "registers an empty hash if no metadata are passed" do
          Registry.register('some permission')
          Registry.all_with_metadata.should == {
            'some permission' => Set.new([{}])
          }
        end

        it "registers in .all when using metadata and permission" do
          Registry.register('some permission', :key => 'value')
          Registry.all.should == Set.new(['some permission'])
        end

        it "registers the same permission with different metadata but .all "\
           "returns the permission only once" do
          Registry.register('some permission', :key => 'value 1')
          Registry.register('some permission', :key => 'value 2')
          Registry.all.should == Set.new(['some permission'])
        end

      end

    end

    describe ".query" do

      # Querying is done against the metadata registered with a permission.

      before do
        Registry.
          register('permission 1', :key_1 => 'value 1', :key_2 => 'value 2')
        Registry.
          register('permission 1', :key_1 => 'unique value')
        Registry.
          register('permission 2', :key_1 => 'value 1')
        Registry.
          register('permission 2', :key_1 => 'other unique value')
      end

      it "returns all permissions if no criteria is passed" do
        Registry.query.should == Registry.all
      end

      it "returns all permissions if an empty hash is passed" do
        Registry.query({}).should == Registry.all
      end

      describe "with single criterion" do

        # A criterion is a hash, whose keys/values must match the metadata of
        # some permission in order of that being returned.

        it "returns permissions matching key => value" do
          results = Registry.query(:key_1 => 'unique value')
          results.should include('permission 1')
        end

        it "doesn't return permissions for which key => value isn't valid" do
          results = Registry.query(:key_1 => 'unique value')
          results.should_not include('permission 2')
        end

        it "accepts multiple key/value pairs (performs AND operation)" do
          results = Registry.query(:key_1 => 'value 1', :key_2 => 'value 2')
          results.should include('permission 1')
          results.should_not include('permission 2')
        end

        it "checks all metadata available in all registrations" do
          results = Registry.query(:key_1 => 'unique value',
                                   :key_2 => 'value 2')
          results.should include('permission 1')
          results.should_not include('permission 2')
        end

      end

      describe "with multiple criteria" do

        # Each argument is a criterion.

        it "accepts multiple hashes (performs OR operation)" do
          results = Registry.query({:key_1 => 'unique value'},
                                   {:key_1 => 'other unique value'})
          results.should include('permission 1')
          results.should include('permission 2')
        end

        it "can combine AND and OR operations" do
          results = Registry.query(
            {:key_1 => 'unique value', :key_2 => 'value 2'},
            {:key_1 => 'other unique value'}
          )
          results.should include('permission 1')
          results.should include('permission 2')
        end

      end

    end

    describe ".register_undeclared_permissions" do

      %w(grant_roles share_own_roles change_inheritance_blocking).each do |p|

        it "registers '#{p}'" do
          Registry.register_undeclared_permissions
          Registry.all.should include(p)
        end

        it "registers '#{p}' with empty metadata" do
          Registry.register_undeclared_permissions
          Registry.all_with_metadata[p].should include({})
        end

        it "accepts metadata" do
          Registry.register_undeclared_permissions(:key => 'value')
          Registry.all_with_metadata[p].should include({:key => 'value'})
        end

        it "is called during initialization phase (so '#{p}' is registered)" do
          # We can't test this in Registry object because it is being cleared
          # in the top "before" block.
          reg_class = Registry.class
          new_registry = reg_class.new
          new_registry.all.should include(p)
        end

      end

    end

  end
end
