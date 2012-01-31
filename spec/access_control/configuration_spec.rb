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
    }.each do |type, default|

      describe "default '#{type}' permissions" do
        let(:getter) { config.public_method("default_#{type}_permissions") }
        let(:setter) { config.public_method("default_#{type}_permissions=") }

        let(:returned_value) { getter.call }

        it "doesn't raise errors when retrieved" do
          lambda {
            getter.call
          }.should_not raise_error
        end

        it "doesn't raise errors when set" do
          lambda {
            setter.call('some permission')
          }.should_not raise_error
        end

        it "can retrieve the '#{type}' permission, returns a set" do
          setter.call('some permission')
          returned_value.should == Set['some permission']

          setter.call(['some permission'])
          returned_value.should == Set['some permission']
        end

        it "accepts an enumerable as a single argument" do
          setter.call(['some permission', 'another permission'])
          returned_value.should == Set['some permission', 'another permission']
        end

        it "accepts nil" do
          setter.call(nil)
          returned_value.should == Set.new
        end

        it "defaults to '#{default}'" do
          returned_value.should == Set[default]
        end

        describe "when #register_permissions is called" do
          it "registers the '#{type}' default permissions" do
            Registry.stub(:store)

            permissions = Set['some permission', 'another permission']
            permissions.each do |permission|
              Registry.should_receive(:store).with(permission)
            end

            setter.call(permissions)
            config.register_permissions
          end

        end

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
