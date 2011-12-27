require 'spec_helper'
require 'access_control/configuration'

module AccessControl
  describe Configuration do

    let(:config) { Configuration.new }

    {
      "show" => 'view',
      "index" => 'list',
      "create" => 'add',
      "update" => 'modify',
      "destroy" => 'delete',
    }.each do |k, v|

      it "can define default #{k} permissions" do
        config.send("default_#{k}_permissions=", 'some permission')
      end

      it "can retrieve the #{k} permission, returns a set" do
        config.send("default_#{k}_permissions=", 'some permission')
        config.send("default_#{k}_permissions").
          should == Set.new(['some permission'])
        config.send("default_#{k}_permissions=", ['some permission'])
        config.send("default_#{k}_permissions").
          should == Set.new(['some permission'])
      end

      it "accepts a list of arguments" do
        config.send("default_#{k}_permissions=",
                    'some permission', 'another permission')
        config.send("default_#{k}_permissions").
          should == Set.new(['some permission', 'another permission'])
      end

      it "accepts an enumerable as a single argument" do
        config.send("default_#{k}_permissions=",
                    ['some permission', 'another permission'])
        config.send("default_#{k}_permissions").
          should == Set.new(['some permission', 'another permission'])
      end

      it "accepts nil" do
        config.send("default_#{k}_permissions=", nil)
        config.send("default_#{k}_permissions").should == Set.new
      end

      it "accepts metadata" do
        config.send("default_#{k}_permissions=", 'some permission',
                    :metadata => 'value')
        config.send("default_#{k}_permissions_metadata").
          should == { :metadata => 'value' }
      end

      it "defaults to '#{v}'" do
        config.send("default_#{k}_permissions").should == Set.new([v])
      end

      it "defaults metadata to {}" do
        config.send("default_#{k}_permissions_metadata").should == {}
      end

      describe "when #register_permissions is called" do

        before { Registry.stub(:register) }

        it "registers the #{k} permission" do
          Registry.should_receive(:register).
            with(Set.new(['some permission', 'another permission']),
                 :metadata => 'value')
          config.send("default_#{k}_permissions=",
                      ['some permission', 'another permission'],
                      :metadata => 'value')
          config.register_permissions
        end

      end

    end

    describe "restrict belongs_to association" do

      it "is disabled by default" do
        config.restrict_belongs_to_association.should == false
      end

      it "can be enabled" do
        config.restrict_belongs_to_association = true
        config.restrict_belongs_to_association.should be_true
      end

    end

    describe "default roles" do

      it "is 'owner' by default" do
        config.default_roles.should == Set['owner']
      end

      it "accepts a single string" do
        config.default_roles = 'other_role'
        config.default_roles.should == Set['other_role']
      end

      it "accepts a list of strings" do
        config.send(:default_roles=, 'role1', 'role2')
        config.default_roles.should == Set['role1', 'role2']
      end

      it "accepts a single enumerable argument" do
        config.default_roles = ['role1', 'role2']
        config.default_roles.should == Set['role1', 'role2']
      end

      it "accepts `nil`" do
        config.default_roles = nil
        config.default_roles.should == Set.new
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
