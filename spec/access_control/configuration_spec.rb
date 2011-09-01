require 'spec_helper'
require 'access_control/configuration'

module AccessControl
  describe Configuration do

    {
      "view" => 'view',
      "query" => 'query',
      "create" => 'add',
      "update" => 'modify',
      "destroy" => 'delete',
    }.each do |k, v|

      it "can define default #{k} permissions" do
        Configuration.new.send("default_#{k}_permissions=",
                               'some permission')
      end

      it "can retrieve the #{k} permission, returns a set" do
        config = Configuration.new
        config.send("default_#{k}_permissions=", 'some permission')
        config.send("default_#{k}_permissions").
          should == Set.new(['some permission'])
        config.send("default_#{k}_permissions=", ['some permission'])
        config.send("default_#{k}_permissions").
          should == Set.new(['some permission'])
      end

      it "accepts a list of arguments" do
        config = Configuration.new
        config.send("default_#{k}_permissions=",
                    'some permission', 'another permission')
        config.send("default_#{k}_permissions").
          should == Set.new(['some permission', 'another permission'])
      end

      it "accepts an enumerable as a single argument" do
        config = Configuration.new
        config.send("default_#{k}_permissions=",
                    ['some permission', 'another permission'])
        config.send("default_#{k}_permissions").
          should == Set.new(['some permission', 'another permission'])
      end

      it "defaults to '#{v}'" do
        Configuration.new.send("default_#{k}_permissions").
          should == Set.new([v])
      end

      describe "when #register_permissions is called" do

        it "registers the #{k} permission" do
          config = Configuration.new
          PermissionRegistry.stub!(:register)
          PermissionRegistry.should_receive(:register).
            with(Set.new(['some permission', 'another permission']))
          config.send("default_#{k}_permissions=",
                      ['some permission', 'another permission'])
          config.register_permissions
        end

      end

    end

    describe "tree_creation" do

      it "is enabled by default" do
        Configuration.new.tree_creation.should be_true
      end

      it "can be disabled" do
        config = Configuration.new
        config.tree_creation = false
        config.tree_creation.should be_false
      end

    end

    describe "restrict belongs_to association" do

      it "is disabled by default" do
        Configuration.new.restrict_belongs_to_association.should == false
      end

      it "can be enabled" do
        config = Configuration.new
        config.restrict_belongs_to_association = true
        config.restrict_belongs_to_association.should be_true
      end

    end

    describe "default roles on create" do

      it "is 'owner' by default" do
        config = Configuration.new
        config.default_roles_on_create.should == Set.new(['owner'])
      end

      it "accepts a single string" do
        config = Configuration.new
        config.default_roles_on_create = 'other_role'
        config.default_roles_on_create.should == Set.new(['other_role'])
      end

      it "accepts a list of strings" do
        config = Configuration.new
        config.send(:default_roles_on_create=, 'role1', 'role2')
        config.default_roles_on_create.should == Set.new(['role1', 'role2'])
      end

      it "accepts a single enumerable argument" do
        config = Configuration.new
        config.default_roles_on_create = ['role1', 'role2']
        config.default_roles_on_create.should == Set.new(['role1', 'role2'])
      end

      it "accepts `nil`" do
        config = Configuration.new
        config.default_roles_on_create = nil
        config.default_roles_on_create.should == Set.new
      end

    end

  end

  describe "configuration API" do

    describe "#configure" do
      it "yields a Configuration object" do
        AccessControl.configure do |config|
          config.is_a?(Configuration).should be_true
        end
      end
      it "yields the same configuration object every time" do
        first = second = nil
        AccessControl.configure{|config| first = config}
        AccessControl.configure{|config| second = config}
        first.should equal(second)
      end
    end

    describe "#config" do
      it "returns a default configuration object" do
        AccessControl.config.is_a?(Configuration)
      end
      it "returns the configuration used in #configure" do
        object = nil
        AccessControl.configure do |config|
          object = config
        end
        object.should equal(AccessControl.config)
      end
    end

  end
end
