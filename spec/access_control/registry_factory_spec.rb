require 'spec_helper'
require 'access_control/configuration'
require 'access_control/registry_factory'

module AccessControl
  describe RegistryFactory do

    subject { RegistryFactory.new }

    before do
      subject.clear_registry
    end

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

      it "indexes the new permission by its name" do
        permission = subject.store("permission")
        subject["permission"].should == permission
      end

      it "re-indexes the new permission by the indexes registered" do
        subject.add_index(:key)

        permission = subject.store("permission") do |permission|
          permission.key = "value"
        end

        subject.query(:key => "value").should include_only(permission)
      end
    end

    describe ".query" do
      it "returns all permissions if given an empty criteria" do
        permission = subject.store("Permission")

        return_value = subject.query({})
        return_value.should include_only(permission)
      end

      it "filters permissions by name" do
        p1 = subject.store("Permission 1")
        p2 = subject.store("Permission 2")

        return_value = subject.query(:name => "Permission 1")
        return_value.should include_only(p1)
      end

      it "filters permissions by indexed fields" do
        subject.add_index(:price)

        p1 = subject.store("Permission 1") { |perm| perm.price = 123 }
        p2 = subject.store("Permission 2") { |perm| perm.price = 456 }

        return_value = subject.query(:price => 123)
        return_value.should include_only(p1)
      end

      it "filters permissions by not-indexed fields" do
        p1 = subject.store("Permission 1") { |perm| perm.price = 123 }
        p2 = subject.store("Permission 2") { |perm| perm.price = 456 }

        return_value = subject.query(:price => 123)
        return_value.should include_only(p1)
      end

      it "may accept a block for custom filtering" do
        p1 = subject.store("Permission 1") { |perm| perm.price = 100 }
        p2 = subject.store("Permission 2") { |perm| perm.price = 200 }
        p3 = subject.store("Permission 3") { |perm| perm.price = 300 }

        return_value = subject.query do |permission|
          permission.price > 100 and permission.price < 300
        end
        return_value.should include_only(p2)
      end
    end

    describe "a index" do
      it "contains the permissions registered after its creation" do
        subject.add_index(:price)
        perm = subject.store("Permission") { |perm| perm.price = 100 }

        return_value = subject.query(:price => 100)
        return_value.should include(perm)
      end

      it "contains the permissions registered before its creation" do
        perm = subject.store("Permission") { |perm| perm.price = 100 }
        subject.add_index(:price)

        return_value = subject.query(:price => 100)
        return_value.should include(perm)
      end

      it "may contain multiple permissions for the same value" do
        subject.add_index(:price)
        p1 = subject.store("Permission 1") { |perm| perm.price = 100 }
        p2 = subject.store("Permission 2") { |perm| perm.price = 100 }

        return_value = subject.query(:price => 100)
        return_value.should include(p1, p2)
      end

      it "ignores permissions whose value for the index is null" do
        subject.add_index(:price)
        perm = subject.store("Permission") { |perm| perm.price = nil }

        return_value = subject.query(:price => nil)
        return_value.should_not include(perm)
      end

      it "ignores permissions that don't have a corresponding method" do
        subject.add_index(:price)
        perm = subject.store("Permission")

        return_value = subject.query(:price => nil)
        return_value.should_not include(perm)
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

        return_value = subject.query(:price => 100)
        return_value.should include_only(p2)
      end
    end

  end
end
