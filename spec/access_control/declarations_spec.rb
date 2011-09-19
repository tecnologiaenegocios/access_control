require 'spec_helper'
require 'access_control/declarations'

module AccessControl
  describe Declarations do

    def set_model(model_name='Record', superclass=Object)
      Object.const_set(model_name, Class.new(superclass){include Declarations})
    end

    def unset_model(model_name='Record')
      Object.send(:remove_const, model_name)
    end

    def model(name='Record')
      name.constantize
    end

    let(:config) { mock('config') }

    before do
      set_model
      AccessControl.stub(:config).and_return(config)
      Declarations::Requirements.clear
    end

    after do
      unset_model
    end

    [
      ['show',    'view'],
      ['index',   'list'],
      ['create',  'add'],
      ['update',  'modify'],
      ['destroy', 'delete'],
    ].each do |t, default|

      describe "#{t} requirement" do

        before do
          config.stub("default_#{t}_permissions").
            and_return(default_permission)
        end

        let(:default_permission) { Set.new([default]) }

        it "can be defined in the class level" do
          model.send("#{t}_requires", 'some permission')
        end

        it "requires at least one permission by default" do
          config.stub("default_#{t}_permissions").and_return(Set.new)
          lambda {
            model.send("permissions_required_to_#{t}")
          }.should raise_exception(MissingPermissionDeclaration)
        end

        it "doesn't require any permission if nil is set" do
          config.stub("default_#{t}_permissions").and_return(Set.new)
          model.send("#{t}_requires", nil)
          model.send("permissions_required_to_#{t}").should == Set.new
        end

        it "can be queried in the class level" do
          model.send("#{t}_requires", 'some permission')
          model.send("permissions_required_to_#{t}").
            should == Set.new(['some permission'])
        end

        it "accepts a list of arguments" do
          model.send("#{t}_requires", 'some permission', 'another permission')
          model.send("permissions_required_to_#{t}").
            should == Set.new(['some permission', 'another permission'])
        end

        it "accepts an enumerable as a single argument" do
          model.send("#{t}_requires",
                     ['some permission', 'another permission'])
          model.send("permissions_required_to_#{t}").
            should == Set.new(['some permission', 'another permission'])
        end

        it "defaults to config's value" do
          model.send("permissions_required_to_#{t}").
            should == default_permission
        end

        it "defaults to config's value even if it changes between calls" do
          config.stub("default_#{t}_permissions").
            and_return(Set.new(['some permission']))
          model.send("permissions_required_to_#{t}").
            should == Set.new(['some permission'])
          config.stub("default_#{t}_permissions").
            and_return(Set.new(['another permission']))
          model.send("permissions_required_to_#{t}").
            should == Set.new(['another permission'])
        end

        it "doesn't mess with the config's value" do
          copy_from_original = Set.new(default_permission.to_a)
          model.send("#{t}_requires", "another permission")
          default_permission.should == copy_from_original
        end

        it "can be inherited by subclasses" do
          subclass = set_model('SubRecord', model)
          model.send("#{t}_requires", 'some permission')
          subclass.send("permissions_required_to_#{t}").
            should == Set.new(['some permission'])
          unset_model('SubRecord')
        end

        it "can be changed in subclasses" do
          subclass = set_model('SubRecord', model)
          model.send("#{t}_requires", 'some permission')
          subclass.send("#{t}_requires", 'another permission')
          subclass.send("permissions_required_to_#{t}").
            should == Set.new(['another permission'])
          unset_model('SubRecord')
        end

        it "doesn't mess with superclass' value" do
          subclass = set_model('SubRecord', model)
          model.send("#{t}_requires", 'some permission')
          subclass.send("#{t}_requires", 'another permission')
          subclass.send("permissions_required_to_#{t}").
            should == Set.new(['another permission'])
          model.send("permissions_required_to_#{t}").
            should == Set.new(['some permission'])
          unset_model('SubRecord')
        end

        it "informs Registry about the permissions" do
          Registry.should_receive(:register).
            with('some permission', :metadata => 'value')
          model.send("#{t}_requires", 'some permission', :metadata => 'value')
        end

        it "doesn't inform Registry if passed nil" do
          Registry.should_not_receive(:register)
          model.send("#{t}_requires", nil)
        end

        describe "when model is reloaded" do

          it "keeps the permissions" do
            model.send("#{t}_requires", 'some permission')
            unset_model
            set_model
            model.send("permissions_required_to_#{t}").
              should == Set.new(['some permission'])
          end

          it "keeps an empty requirement" do
            model.send("#{t}_requires", nil)
            unset_model
            set_model
            model.send("permissions_required_to_#{t}").should == Set.new
          end

        end

      end

      describe "additional #{t} requirement" do

        let(:default_permission) { Set.new([default]) }

        it "can be defined in class level" do
          model.send("add_#{t}_requirement", 'some permission')
        end

        it "can be queried in class level, merges with current permissions" do
          config.stub("default_#{t}_permissions").
            and_return(Set.new(['some permission']))
          model.send("add_#{t}_requirement", 'another permission')
          model.send("permissions_required_to_#{t}").
            should == Set.new(['some permission', 'another permission'])
        end

        it "accepts a list of arguments" do
          config.stub("default_#{t}_permissions").and_return(Set.new)
          model.send("add_#{t}_requirement", 'some permission',
                     'another permission')
          model.send("permissions_required_to_#{t}").
            should == Set.new(['some permission', 'another permission'])
        end

        it "accepts an enumerable as a single argument" do
          config.stub("default_#{t}_permissions").and_return(Set.new)
          model.send("add_#{t}_requirement",
                     ['some permission', 'another permission'])
          model.send("permissions_required_to_#{t}").
            should == Set.new(['some permission', 'another permission'])
        end

        it "doesn't mess with the config's value" do
          copy_from_original = Set.new(default_permission.to_a)
          model.send("add_#{t}_requirement", "another permission")
          default_permission.should == copy_from_original
        end

        it "can set additional permissions if ##{t}_requires was set" do
          # Config is not taken into account because of the explicit
          # declaration.
          model.send("#{t}_requires", 'some permission')
          model.send("add_#{t}_requirement", "another permission")
          model.send("permissions_required_to_#{t}").
            should == Set.new(['some permission', 'another permission'])
        end

        it "combines permissions from superclasses" do
          # Config is not taken into account because of the explicit
          # declaration.
          subclass = set_model('SubRecord', model)
          model.send("#{t}_requires", 'some permission')
          subclass.send("add_#{t}_requirement", "another permission")
          subclass.send("permissions_required_to_#{t}").
            should == Set.new(['some permission', 'another permission'])
          unset_model('SubRecord')
        end

        it "doesn't mess with superclass' value" do
          # Config is not taken into account because of the explicit
          # declaration.
          subclass = set_model('SubRecord', model)
          model.send("#{t}_requires", 'some permission')
          subclass.send("add_#{t}_requirement", 'another permission')
          model.send("permissions_required_to_#{t}").
            should == Set.new(['some permission'])
          unset_model('SubRecord')
        end

        it "combines permissions from superclasses and config" do
          config.stub("default_#{t}_permissions").
            and_return(Set.new(['permission one']))
          subclass = set_model('SubRecord', model)
          model.send("add_#{t}_requirement", 'permission two')
          subclass.send("add_#{t}_requirement", 'permission three')
          subclass.send("permissions_required_to_#{t}").
            should == Set.new(['permission one', 'permission two',
                               'permission three'])
          unset_model('SubRecord')
        end

        it "informs Registry about the permissions" do
          Registry.should_receive(:register).
            with('some permission', :metadata => 'value')
          model.send("add_#{t}_requirement", 'some permission',
                     :metadata => 'value')
        end

        describe "when model is reloaded" do

          it "keeps the permissions" do
            config.stub("default_#{t}_permissions").and_return(Set.new)
            model.send("add_#{t}_requirement", 'some permission')
            unset_model
            set_model
            model.send("permissions_required_to_#{t}").
              should == Set.new(['some permission'])
          end

        end

      end

    end
  end
end
