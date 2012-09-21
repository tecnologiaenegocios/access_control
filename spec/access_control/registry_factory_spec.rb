require 'support/matchers/include_only'
require 'access_control/registry_factory'
require 'access_control/exceptions'

module AccessControl
  describe RegistryFactory do
    let(:permission_factory) do
      lambda do |permission_name|
        OpenStruct.new(:name => permission_name)
      end
    end

    let(:methodless_permission_factory) do
      methodless_permission = Struct.new(:name)
      lambda do |name|
        methodless_permission.new(name)
      end
    end

    subject { RegistryFactory.new(permission_factory) }

    describe "#store" do
      it "registers a permission with the given name" do
        permission = subject.store("permission")
        subject.all.should include(permission)
      end

      it "when given a block, yields the new permission to it" do
        yielded_object = nil
        new_permission = subject.store("permission") do |permission|
          yielded_object = permission
        end

        yielded_object.should == new_permission
      end

      it "doesn't override permissions previously added" do
        permission = subject.store("permission")
        other_permission = subject.store("permission")

        other_permission.should be permission
      end

      it "indexes the new permission by its name" do
        permission = subject.store("permission")
        subject["permission"].should == permission
      end

      it "re-indexes the new permission by the indexes registered" do
        value = stub
        subject.add_index(:key)

        stored_permission = subject.store("permission") do |permission|
          permission.key = value
        end

        subject.query(:key => value).should include_only(stored_permission)
      end

      specify "when a permission is #store'd the second time, re-indexes it" do
        value = stub
        subject.add_index(:key)

        subject.store("permission")
        permission = subject.store("permission") { |perm| perm.key = value }

        subject.query(:key => value).should include_only(permission)
      end
    end

    describe "#unstore" do
      # RegistryFactory#unstore is designed for situations when you have
      # registered a single permission in a spec and don't want to clear all
      # the registry just to not carry state from a spec to another.  It will
      # probably not be useful outside tests.
      before do
        subject.add_index(:key)
        subject.add_collection_index(:collection)
      end

      context "when there's a registered permission with the given name" do
        let(:value)  { stub }
        let(:values) { [stub, stub] }

        before do
          subject.store('permission') do |permission|
            permission.key = value
            permission.collection = values
          end
        end

        it "unregisters the permission" do
          subject.unstore('permission')
          subject.all.should be_empty
        end

        describe "unindexing" do
          it "unindexes the permission at the 'name' index" do
            subject.unstore('permission')
            subject['permission'].should be_nil
          end

          it "unindexes the permission at the other normal indexes" do
            subject.unstore('permission')
            subject.query(:key => value).should be_empty
          end

          it "unindexes the permission at the collection indexes" do
            subject.unstore('permission')
            subject.query(:collection => [values[0]]).should be_empty
            subject.query(:collection => [values[1]]).should be_empty
          end
        end
      end

      context "when there's no permission registered under the given name" do
        it "does nothing" do
          lambda {
            subject.unstore('unregistered permission')
          }.should_not raise_exception
        end
      end
    end

    describe "#destroy" do
      let(:permission_manager) { mock("Permission manager") }
      let(:permission)         { subject.store("Permission") }

      before do
        subject.permission_manager = permission_manager
      end

      it "asks the permission manager to destroy the permission" do
        permission_manager.should_receive(:destroy_permission).with(permission)
        subject.destroy(permission)
      end
    end

    describe "#fetch" do
      it "returns a permission whose name matches the parameter given" do
        p1 = subject.store('Permission 1')
        subject.fetch('Permission 1').should be p1
      end

      context "when no permission is found with that name" do
        context "and no block is given" do
          it "raises NotFoundError if no default is given" do
            lambda {
              subject.fetch('Inexistent')
            }.should raise_exception(NotFoundError)
          end

          it "returns the default if given" do
            default = stub
            subject.fetch('Inexistent', default).should be default
          end
        end

        context "and a block is given" do
          it "uses the block if no default is given" do
            default = stub
            returned_value = subject.fetch('Inexistent') { default }
            returned_value.should be default
          end

          it "uses the block even if a default is given" do
            value_default = stub('as forma argument')
            block_default = stub('from block result')
            returned_value = subject.fetch('Inexistent', value_default) do
              block_default
            end
            returned_value.should be block_default
          end
        end
      end
    end

    describe "#fetch_all" do
      it "returns all permissions with the given names" do
        p1 = subject.store("Permission 1")
        p2 = subject.store("Permission 2")

        returned_value = subject.fetch_all(['Permission 1', 'Permission 2'])
        returned_value.should include_only(p1, p2)
      end

      it "works with a set" do
        p1 = subject.store("Permission 1")
        p2 = subject.store("Permission 2")

        returned_value = subject.fetch_all(Set['Permission 1', 'Permission 2'])
        returned_value.should include_only(p1, p2)
      end

      it "raises NotFoundError if any of the permissions is missing" do
        subject.store("Permission 1")
        subject.store("Permission 3")

        lambda {
          subject.fetch_all(['Permission 1', 'Permission 2'])
        }.should raise_exception(NotFoundError)
      end
    end

    describe "#query" do
      it "returns all permissions if given an empty criteria" do
        permission = subject.store("Permission")

        returned_value = subject.query({})
        returned_value.should include_only(permission)
      end

      it "filters permissions by name" do
        p1 = subject.store("Permission 1")
        subject.store("Permission 2")

        returned_value = subject.query(:name => "Permission 1")
        returned_value.should include_only(p1)
      end

      it "filters permissions by indexed fields" do
        subject.add_index(:price)

        p1 = subject.store("Permission 1") { |perm| perm.price = 123 }
        subject.store("Permission 2") { |perm| perm.price = 456 }

        returned_value = subject.query(:price => 123)
        returned_value.should include_only(p1)
      end

      it "filters permissions by not-indexed fields" do
        p1 = subject.store("Permission 1") { |perm| perm.price = 123 }
        subject.store("Permission 2") { |perm| perm.price = 456 }

        returned_value = subject.query(:price => 123)
        returned_value.should include_only(p1)
      end

      context "for collection indexes" do
        before do
          subject.add_collection_index(:prices)
        end

        it "returns permissions that include all the values passed" do
          stored_permission = subject.store("Permission") do |perm|
            perm.prices = [123,456]
          end

          returned_value = subject.query(:prices => [123, 456])
          returned_value.should include(stored_permission)
        end

        it "returns permissions that include one of the values passed" do
          stored_permission = subject.store("Permission") do |perm|
            perm.prices = [123]
          end

          returned_value = subject.query(:prices => [123, 456])
          returned_value.should include(stored_permission)
        end

        it "doesn't return permissions that include none of the values" do
          stored_permission = subject.store("Permission") do |perm|
            perm.prices = [789]
          end

          returned_value = subject.query(:prices => [123, 456])
          returned_value.should_not include(stored_permission)
        end

        it "returns all permissions that have at least one value" do
          p1 = subject.store("Permission 1") { |perm| perm.prices = [123,456] }
          p2 = subject.store("Permission 2") { |perm| perm.prices = [456,789] }

          returned_value = subject.query(:prices => [456])
          returned_value.should include(p1, p2)
        end

        it "can mix collection and non-collection indexes" do
          subject.add_index(:flag)

          p1 = subject.store("Permission 1") do |perm|
            perm.prices = [123,456]
            perm.flag   = true
          end

          subject.store("Permission 2") do |perm|
            perm.prices = [456,789]
            perm.flag   = false
          end

          subject.store("Permission 3") do |perm|
            perm.prices = [123,789]
            perm.flag   = true
          end

          returned_value = subject.query(:prices => [456], :flag => true)
          returned_value.should include_only(p1)
        end

        it "can mix collection and block-based queries" do
          p1 = subject.store("Permission 1") do |perm|
            perm.prices = [123,456]
            perm.flag   = true
          end

          subject.store("Permission 2") do |perm|
            perm.prices = [456,789]
            perm.flag   = false
          end

          subject.store("Permission 3") do |perm|
            perm.prices = [123,789]
            perm.flag   = true
          end

          returned_value = subject.query(:prices => [456]) do |perm|
            perm.flag == true
          end

          returned_value.should include_only(p1)
        end
      end

      it "may accept a block for custom filtering" do
        subject.store("Permission 1") { |perm| perm.price = 100 }
        p1 = subject.store("Permission 2") { |perm| perm.price = 200 }
        subject.store("Permission 3") { |perm| perm.price = 300 }

        returned_value = subject.query do |permission|
          permission.price > 100 and permission.price < 300
        end
        returned_value.should include_only(p1)
      end
    end

    describe "an index" do
      it "contains the permissions registered after its creation" do
        subject.add_index(:price)
        stored_permission = subject.store("Permission") do |permission|
          permission.price = 100
        end

        returned_value = subject.query(:price => 100)
        returned_value.should include(stored_permission)
      end

      it "contains the permissions registered before its creation" do
        stored_permission = subject.store("Permission") do |permission|
          permission.price = 100
        end
        subject.add_index(:price)

        returned_value = subject.query(:price => 100)
        returned_value.should include(stored_permission)
      end

      it "may contain multiple permissions for the same value" do
        subject.add_index(:price)
        p1 = subject.store("Permission 1") { |perm| perm.price = 100 }
        p2 = subject.store("Permission 2") { |perm| perm.price = 100 }

        returned_value = subject.query(:price => 100)
        returned_value.should include(p1, p2)
      end

      it "ignores permissions whose value for the index is null" do
        subject.add_index(:price)
        stored_permission = subject.store("Permission") do |permission|
          permission.price = nil
        end

        returned_value = subject.query(:price => nil)
        returned_value.should_not include(stored_permission)
      end

      it "ignores permissions that don't have a corresponding method" do
        subject = RegistryFactory.new(methodless_permission_factory)
        subject.add_index(:price)

        perm = subject.store("Permission")

        returned_value = subject.query(:price => nil)
        returned_value.should_not include(perm)
      end
    end

    describe "collection-based indexes" do
      it "associate the same permission to multiple values" do
        subject.add_collection_index(:prices)
        stored_permission = subject.store("Permission") do |permission|
          permission.prices = [100, 200]
        end

        subject.query(:prices => [100, 200]).should include stored_permission
        subject.query(:prices => [200]).should include stored_permission
        subject.query(:prices => [100]).should include stored_permission
      end

      it "may contain multiple permissions for overlapping values" do
        subject.add_collection_index(:prices)
        p1 = subject.store("Permission 1") { |perm| perm.prices = [100, 200] }
        p2 = subject.store("Permission 2") { |perm| perm.prices = [200, 300] }

        returned_value = subject.query(:prices => [200])
        returned_value.should include(p1, p2)
      end

      it "ignores permissions whose value for the index is empty" do
        subject.add_collection_index(:prices)
        stored_permission = subject.store("Permission") do |permission|
          permission.prices = []
        end

        returned_value = subject.query(:prices => [])
        returned_value.should_not include(stored_permission)
      end

      it "ignores permissions that don't have a corresponding method" do
        subject = RegistryFactory.new(methodless_permission_factory)
        subject.add_collection_index(:prices)

        perm = subject.store("Permission")

        returned_value = subject.query(:prices => [])
        returned_value.should_not include(perm)
      end
    end

    describe "#clear" do
      it "removes all the added permissions" do
        perm = subject.store("Permission")
        subject.clear

        subject.all.should_not include(perm)
      end

      it "clears all the indexes" do
        subject.add_index(:price)
        subject.store("Permission 1") { |perm| perm.price = 100 }
        subject.clear
        p1 = subject.store("Permission 2") { |perm| perm.price = 100 }

        returned_value = subject.query(:price => 100)
        returned_value.should include_only(p1)
      end
    end
  end
end
