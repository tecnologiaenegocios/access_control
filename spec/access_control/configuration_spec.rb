require 'access_control/configuration'
require 'support/matchers/include_only'

module AccessControl
  describe Configuration do

    let(:config) { Configuration.new }

    before do
      Registry.stub(:store)
      Registry.stub(:fetch_all) do |permissions|
        permissions.map { |name| stub(:name => name) }
      end
    end

    {
      "show" => 'view',
      "index" => 'list',
      "create" => 'add',
      "update" => 'modify',
      "destroy" => 'delete',
    }.each do |type, default|

      describe "default '#{type}' permissions" do
        let(:getter) { config.public_method("permissions_required_to_#{type}") }
        let(:setter) { config.public_method("#{type}_requires") }

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

        it "can retrieve the '#{type}' permission" do
          setter.call('some permission')
          returned_value.map(&:name).to_set.should == Set['some permission']

          setter.call(['some permission'])
          returned_value.map(&:name).to_set.should == Set['some permission']
        end

        it "returns a set" do
          setter.call('some permission')
          returned_value.should be_a(Set)
        end

        it "accepts an enumerable as a single argument" do
          setter.call(['some permission', 'another permission'])
          returned_value.map(&:name).to_set.should ==
            Set['some permission', 'another permission']
        end

        it "accepts nil" do
          setter.call(nil)
          returned_value.should == Set.new
        end

        it "defaults to empty set" do
          returned_value.should == Set.new
        end

        it "registers the permissions set" do
          Registry.should_receive(:store).with('some permission')
          setter.call(['some permission'])
        end

        it "accepts a block for additional metadata setting" do
          p = stub
          Registry.stub(:store).with('some permission').and_yield(p)
          setter.call(['some permission']) do |permission|
            permission.should be p
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

    describe "#extend_permissions" do
      it "evaluates the received block on the context of Permission" do
        execution_context = nil
        config.extend_permissions do
          execution_context = self
        end

        execution_context.should == RegistryFactory::Permission
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
