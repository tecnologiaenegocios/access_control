require 'access_control/macros'
require 'support/matchers/include_only'

module AccessControl
  describe Macros do

    def model_class(options = {})
      superclass = options[:inheriting_from] || Object
      name       = superclass != Object ? "Sub#{superclass.name}" : "Record"

      Class.new(superclass) do
        extend Macros

        define_singleton_method(:name) do
          name
        end

        def initialize(foo=nil)
          @foo = foo
        end

        def foo
          @foo
        end
      end
    end

    let(:model)    { model_class }
    let(:registry) { stub }
    let(:config)   { mock('config') }

    before do
      AccessControl.stub(:config).and_return(config)
      AccessControl.stub(:registry).and_return(registry)
      AccessControl::Macros.clear

      registry.define_singleton_method(:store) do |permission_name, &block|
        permission = RegistryFactory::Permission.new(permission_name)
        block.call(permission) if block
      end

      registry.stub(:fetch_all) do |permission_names|
        permission_names.map { |name| stub(:name => name) }
      end

      [:show, :list, :create, :update, :destroy].each do |type|
        config.stub("permissions_required_to_#{type}") { Set.new }
      end
    end

    def define_default_permissions
      [
        ['show',    'view'],
        ['list',   'list'],
        ['create',  'add'],
        ['update',  'modify'],
        ['destroy', 'delete'],
      ].each do |t, default|
        config.stub("permissions_required_to_#{t}").
          and_return(Set[stub(:name => default)])
      end
    end

    [
      ['show',    'view'],
      ['list',   'list'],
      ['create',  'add'],
      ['update',  'modify'],
      ['destroy', 'delete'],
    ].each do |t, default_permission|
      def required_permissions_names(model_class = model)
        getter_for(model_class).call.map(&:name).to_set
      end

      def set_permissions_names(*names, &block)
        set_permissions_names_of(model, *names, &block)
      end

      def set_permissions_names_of(model_class, *names, &block)
        setter_for(model_class).call(*names, &block)
      end

      describe "#{t} requirement" do
        before do
          define_default_permissions
        end

        define_method(:getter_for) do |model_class|
          model_class.method("permissions_required_to_#{t}")
        end

        define_method(:setter_for) do |model_class|
          model_class.method("#{t}_requires")
        end

        it "can be defined in the class level" do
          lambda {
            set_permissions_names('some permission')
          }.should_not raise_error
        end

        it "can be queried in the class level" do
          set_permissions_names('some permission')
          required_permissions_names.
            should include_only('some permission')
        end

        specify "querying returns only permissions names, not instances" do
          set_permissions_names('some permission')
          required_permissions_names.
            should include_only('some permission')
        end

        it "accepts a list of arguments" do
          set_permissions_names('some permission', 'another permission')
          required_permissions_names.
            should include_only('some permission', 'another permission')
        end

        it "accepts an enumerable as a single argument" do
          set_permissions_names(['some permission',
                                 'another permission'])
          required_permissions_names.
            should include_only('some permission', 'another permission')
        end

        it "defaults to config's value" do
          required_permissions_names.should include_only(default_permission)
        end

        it "defaults to config's value even if it changes between calls" do
          config.stub("permissions_required_to_#{t}").
            and_return(Set[stub(:name => 'some permission')])

          required_permissions_names.should include_only('some permission')

          config.stub("permissions_required_to_#{t}").
            and_return(Set[stub(:name => 'another permission')])

          required_permissions_names.should include_only('another permission')
        end

        it "doesn't mess with the config's value" do
          old_config_permissions = Set.new(config.send("permissions_required_to_#{t}").to_a)
          set_permissions_names("another permission")

          new_config_permissions = config.send("permissions_required_to_#{t}")
          new_config_permissions.should == old_config_permissions
        end

        it "can be inherited by subclasses" do
          subclass = model_class(:inheriting_from => model)
          set_permissions_names('some permission')
          required_permissions_names(subclass).
            should == Set['some permission']
        end

        it "can be changed in subclasses" do
          subclass = model_class(:inheriting_from => model)
          set_permissions_names('some permission')
          set_permissions_names_of(subclass, 'another permission')

          required_permissions_names(subclass).should
            include_only('another permission')
        end

        it "doesn't mess with superclass' value" do
          subclass = model_class(:inheriting_from => model)
          set_permissions_names('some permission')
          set_permissions_names_of(subclass, 'another permission')
          required_permissions_names(subclass).
            should include_only('another permission')

          required_permissions_names.should include_only('some permission')
        end

        it 'can be set to nil, which means "no permissions"' do
          set_permissions_names(nil)
          model.send("permissions_required_to_#{t}").should be_empty
        end

        it "informs Registry about the permissions" do
          registry.should_receive(:store).with('some permission')
          set_permissions_names('some permission')
        end

        it "passes given block to Registry's store method" do
          testpoint = stub
          testpoint.should_receive(:received_permission).with('some permission')

          set_permissions_names('some permission') do |permission|
            testpoint.received_permission(permission.name)
          end
        end

        it "doesn't inform Registry if explicitly set no permissions" do
          registry.should_not_receive(:store)
          set_permissions_names(nil)
        end

        specify "allocation is fine if a permission is set in config" do
          object = model.allocate
          object.class.should == model
        end

        specify "allocation is fine if a permission is set in the model" do
          set_permissions_names('some permission')
          object = model.allocate
          object.class.should == model
        end

        specify "allocation is fine if a permission is explicitly omitted" do
          set_permissions_names(nil)
          object = model.allocate
          object.class.should == model
        end

        specify "instantiation is fine if a permission is set in config" do
          object = model.new('foo')
          object.class.should == model
          object.foo.should == 'foo'
        end

        specify "instantiation is fine if a permission is set in the model" do
          set_permissions_names('some permission')
          object = model.new('foo')
          object.class.should == model
          object.foo.should == 'foo'
        end

        specify "instantiation is fine if a permission is explicitly omitted" do
          set_permissions_names(nil)
          object = model.new('foo')
          object.class.should == model
          object.foo.should == 'foo'
        end

        describe "for two objects with the same 'name'" do

          let(:reloaded_model) { model_class }

          before do
            model.stub(:name => "Record")
            reloaded_model.stub(:name => "Record")
          end

          specify "the requiremenents are the same" do
            set_permissions_names('some permission')

            reloaded_model.send("permissions_required_to_#{t}").map(&:name).
              should include_only("some permission")
          end

          specify "the permissions are the same" do
            config.stub("permissions_required_to_#{t}").and_return(Set.new)
            model.send("add_#{t}_requirement", 'some permission')
            required_permissions_names(reloaded_model).
              should == Set['some permission']
          end

          specify "if one has empty requiremements, the other also has" do
            set_permissions_names(nil)
            reloaded_model.send("permissions_required_to_#{t}").should be_empty
          end
        end

        context "checking permission declarations in the class" do
          before do
            config.stub("permissions_required_to_#{t}").and_return(Set.new)
          end

          context "in singletons" do
            it "doesn't check for declarations" do
              model.send(:include, Singleton)
              lambda { model.instance }.
                should_not raise_exception(MissingPermissionDeclaration)
            end
          end

          context "allocation" do
            it "requires at least one permission by default on allocation" do
              lambda {
                model.allocate
              }.should raise_exception(MissingPermissionDeclaration)
            end
          end

          context "instantiation" do
            it "requires at least one permission by default on instantiation" do
              lambda {
                model.new
              }.should raise_exception(MissingPermissionDeclaration)
            end
          end

        end
      end

      describe "additional #{t} requirement" do
        before do
          define_default_permissions
        end

        let(:default_permission) { Set[default] }

        it "can be defined in class level" do
          model.send("add_#{t}_requirement", 'some permission')
        end

        it "can be queried in class level, merges with current permissions" do
          config.stub("permissions_required_to_#{t}").
            and_return(Set[stub(:name => 'some permission')])
          model.send("add_#{t}_requirement", 'another permission')
          model.send("permissions_required_to_#{t}").map(&:name).to_set.
            should == Set['some permission', 'another permission']
        end

        it "accepts a list of arguments" do
          config.stub("permissions_required_to_#{t}").and_return(Set.new)
          model.send("add_#{t}_requirement", 'some permission',
                     'another permission')
          model.send("permissions_required_to_#{t}").map(&:name).to_set.
            should == Set['some permission', 'another permission']
        end

        it "accepts an enumerable as a single argument" do
          config.stub("permissions_required_to_#{t}").and_return(Set.new)
          model.send("add_#{t}_requirement",
                     ['some permission', 'another permission'])
          model.send("permissions_required_to_#{t}").map(&:name).to_set.
            should == Set['some permission', 'another permission']
        end

        it "doesn't mess with the config's value" do
          old_config_permissions = Set.new(config.send("permissions_required_to_#{t}").to_a)
          model.send("add_#{t}_requirement", "another permission")

          new_config_permissions = config.send("permissions_required_to_#{t}")
          new_config_permissions.should == old_config_permissions
        end

        it "can set additional permissions if ##{t}_requires was set" do
          # Config is not taken into account because of the explicit
          # declaration.
          model.send("#{t}_requires", 'some permission')
          model.send("add_#{t}_requirement", "another permission")
          model.send("permissions_required_to_#{t}").map(&:name).to_set.
            should == Set['some permission', 'another permission']
        end

        it "combines permissions from superclasses" do
          # Config is not taken into account because of the explicit
          # declaration.
          subclass = model_class(:inheriting_from => model)
          model.send("#{t}_requires", 'some permission')
          subclass.send("add_#{t}_requirement", "another permission")
          subclass.send("permissions_required_to_#{t}").map(&:name).to_set.
            should == Set['some permission', 'another permission']
        end

        it "doesn't mess with superclass' value" do
          # Config is not taken into account because of the explicit
          # declaration.
          subclass = model_class(:inheriting_from => model)
          model.send("#{t}_requires", 'some permission')
          subclass.send("add_#{t}_requirement", 'another permission')
          model.send("permissions_required_to_#{t}").map(&:name).to_set.
            should == Set['some permission']
        end

        it "combines permissions from superclasses and config" do
          config.stub("permissions_required_to_#{t}").
            and_return(Set[stub(:name => 'permission one')])
          subclass = model_class(:inheriting_from => model)
          model.send("add_#{t}_requirement", 'permission two')
          subclass.send("add_#{t}_requirement", 'permission three')
          subclass.send("permissions_required_to_#{t}").map(&:name).to_set.
            should == Set.new(['permission one', 'permission two',
                               'permission three'])
        end

        it "informs Registry about the permissions" do
          registry.should_receive(:store).with('some permission')
          model.send("add_#{t}_requirement", 'some permission')
        end

        it "passes given block to Registry's store method" do
          testpoint = stub
          testpoint.should_receive(:received_permission).with('some permission')

          model.send("add_#{t}_requirement", 'some permission') do |permission|
            testpoint.received_permission(permission.name)
          end
        end
      end

    end

    describe ".requires_no_permissions!" do
      let(:requirement_types) do
        [:show, :list, :create, :update, :destroy]
      end

      let(:model_class) do
        Class.new do
          extend Macros
        end
      end

      def add_requirements_to(model_class)
        requirement_types.each do |type|
          model_class.public_send("#{type}_requires", "foo", "bar")
        end
      end

      def expect_no_requirements_on(model_class)
        requirement_types.each do |type|
          requirements = model_class.public_send("permissions_required_to_#{type}")

          error_message = "expected to have no #{type} requirements!"
          requirements.should(be_empty, error_message)
        end
      end

      it "removes all restrictions from the class" do
        add_requirements_to(model_class)
        model_class.requires_no_permissions!
        expect_no_requirements_on(model_class)
      end

      it "makes protected methods not raise 'missing declaration' anymore" do
        model_class.requires_no_permissions!

        lambda {
          model_class.new
        }.should_not raise_error(AccessControl::MissingPermissionDeclaration)
      end
    end

    describe "removing restrictions from methods" do
      let(:instance) { model.new }
      let(:manager)  { stub("Manager") }

      before do
        define_default_permissions
        AccessControl.stub(:manager => manager)

        manager.define_singleton_method(:trust) do |&block|
          block.call
        end
      end

      describe ".define_define_unrestricted_method" do
        it "defines an instance method with the same name as the parameter" do
          model.define_unrestricted_method(:trusted_method) { }
          instance.should respond_to(:trusted_method)
        end

        it "defines a method that has the same behavior as the given block" do
          my_internal_value = stub

          model.define_unrestricted_method(:trusted_method) do
            my_internal_value
          end

          instance.trusted_method.should equal my_internal_value
        end

        it "defines a method that receives the arguments as any regular method" do
          model.define_unrestricted_method(:sum) do |value1, value2|
            value1 + value2
          end

          instance.sum(100, 200).should == 300
        end

        it "defines a method that receives blocks normally" do
          internal_vaue = stub

          model.define_unrestricted_method(:block_based_method) do |&block|
            block.call
          end

          instance.block_based_method { internal_vaue }.should == internal_vaue
        end

        it "defines a method that runs inside a 'trusted' manager block" do
          callstack = []

          manager.define_singleton_method(:trust) do |&block|
            callstack << :trust_start
            block.call
            callstack << :trust_end
          end

          model.define_unrestricted_method(:trusted_method) do
            callstack << :block
          end

          instance.trusted_method
          callstack.should == [:trust_start, :block, :trust_end]
        end
      end

      describe ".unrestrict_method" do
        let(:return_value) { stub("Return value") }

        it "delegates its job to AccessControl.unrestrict_method" do
          AccessControl.should_receive(:unrestrict_method).
            with(model, :method_name)

          model.unrestrict_method(:method_name)
        end
      end
    end

    describe ".clear" do
      before do
        model.class_eval { show_requires 'some permission' }
        AccessControl::Macros.clear
      end

      it "clears macro requirements" do
        model.permissions_required_to_show.should be_empty
      end
    end
  end
end
