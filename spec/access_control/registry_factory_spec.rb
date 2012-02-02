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

    describe ".store" do
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

        permission = subject.store("permission") do |permission|
          permission.key = value
        end

        subject.query(:key => value).should include_only(permission)
      end

      specify "when a permission is #store'd the second time, re-indexes it" do
        value = stub
        subject.add_index(:key)

        subject.store("permission")
        permission = subject.store("permission") { |perm| perm.key = value }

        subject.query(:key => value).should include_only(permission)
      end
    end

    describe ".fetch" do
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

    describe ".fetch_all" do
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
        p1 = subject.store("Permission 1")
        p2 = subject.store("Permission 3")

        lambda {
          subject.fetch_all(['Permission 1', 'Permission 2'])
        }.should raise_exception(NotFoundError)
      end
    end

    describe ".query" do
      it "returns all permissions if given an empty criteria" do
        permission = subject.store("Permission")

        returned_value = subject.query({})
        returned_value.should include_only(permission)
      end

      it "filters permissions by name" do
        p1 = subject.store("Permission 1")
        p2 = subject.store("Permission 2")

        returned_value = subject.query(:name => "Permission 1")
        returned_value.should include_only(p1)
      end

      it "filters permissions by indexed fields" do
        subject.add_index(:price)

        p1 = subject.store("Permission 1") { |perm| perm.price = 123 }
        p2 = subject.store("Permission 2") { |perm| perm.price = 456 }

        returned_value = subject.query(:price => 123)
        returned_value.should include_only(p1)
      end

      it "filters permissions by not-indexed fields" do
        p1 = subject.store("Permission 1") { |perm| perm.price = 123 }
        p2 = subject.store("Permission 2") { |perm| perm.price = 456 }

        returned_value = subject.query(:price => 123)
        returned_value.should include_only(p1)
      end

      context "for collection indexes" do
        before do
          subject.add_collection_index(:prices)
        end

        it "returns permissions that include all the values passed" do
          perm = subject.store("Permission") { |perm| perm.prices = [123,456] }

          returned_value = subject.query(:prices => [123, 456])
          returned_value.should include(perm)
        end

        it "returns permissions that include one of the values passed" do
          perm = subject.store("Permission") { |perm| perm.prices = [123] }

          returned_value = subject.query(:prices => [123, 456])
          returned_value.should include(perm)
        end

        it "doesn't return permissions that include none of the values" do
          perm = subject.store("Permission") { |perm| perm.prices = [789] }

          returned_value = subject.query(:prices => [123, 456])
          returned_value.should_not include(perm)
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

          p2 = subject.store("Permission 2") do |perm|
            perm.prices = [456,789]
            perm.flag   = false
          end

          p3 = subject.store("Permission 3") do |perm|
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

          p2 = subject.store("Permission 2") do |perm|
            perm.prices = [456,789]
            perm.flag   = false
          end

          p3 = subject.store("Permission 3") do |perm|
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
        p1 = subject.store("Permission 1") { |perm| perm.price = 100 }
        p2 = subject.store("Permission 2") { |perm| perm.price = 200 }
        p3 = subject.store("Permission 3") { |perm| perm.price = 300 }

        returned_value = subject.query do |permission|
          permission.price > 100 and permission.price < 300
        end
        returned_value.should include_only(p2)
      end
    end

    describe "an index" do
      it "contains the permissions registered after its creation" do
        subject.add_index(:price)
        perm = subject.store("Permission") { |perm| perm.price = 100 }

        returned_value = subject.query(:price => 100)
        returned_value.should include(perm)
      end

      it "contains the permissions registered before its creation" do
        perm = subject.store("Permission") { |perm| perm.price = 100 }
        subject.add_index(:price)

        returned_value = subject.query(:price => 100)
        returned_value.should include(perm)
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
        perm = subject.store("Permission") { |perm| perm.price = nil }

        returned_value = subject.query(:price => nil)
        returned_value.should_not include(perm)
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
        perm = subject.store("Permission") { |perm| perm.prices = [100, 200] }

        subject.query(:prices => [100, 200]).should include perm
        subject.query(:prices => [200]).should include perm
        subject.query(:prices => [100]).should include perm
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
        perm = subject.store("Permission") { |perm| perm.prices = [] }

        returned_value = subject.query(:prices => [])
        returned_value.should_not include(perm)
      end

      it "ignores permissions that don't have a corresponding method" do
        subject = RegistryFactory.new(methodless_permission_factory)
        subject.add_collection_index(:prices)

        perm = subject.store("Permission")

        returned_value = subject.query(:prices => [])
        returned_value.should_not include(perm)
      end
    end

    describe ".clear_registry" do
      it "removes all the added permissions" do
        perm = subject.store("Permission")
        subject.clear_registry

        subject.all.should_not include(perm)
      end

      it "clears all the indexes" do
        subject.add_index(:price)
        p1 = subject.store("Permission 1") { |perm| perm.price = 100 }
        subject.clear_registry
        p2 = subject.store("Permission 2") { |perm| perm.price = 100 }

        returned_value = subject.query(:price => 100)
        returned_value.should include_only(p2)
      end
    end

  end
end
