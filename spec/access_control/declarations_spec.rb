require 'spec_helper'
require 'access_control/declarations'

module AccessControl
  describe Declarations do

    [
      ["view requirement",    'view',     'view'],
      ["query requirement",   'query',    'query'],
      ["create requirement",  'create',   'add'],
      ["update requirement",  'update',   'modify'],
      ["destroy requirement", 'destroy',  'delete'],
    ].each do |r, t, default|

      let(:model) { Class.new { def self.name; 'Record'; end } }
      let(:config) { mock('config') }

      before do
        model.send(:include, Declarations)
        AccessControl.stub(:config).and_return(config)
        config.stub("default_#{t}_permissions").and_return(default_permission)
      end

      describe r do

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

        it "doesn't require any permission if :none is set" do
          config.stub("default_#{t}_permissions").and_return(Set.new)
          model.send("#{t}_requires", :none)
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
          subclass = Class.new(model)
          model.send("#{t}_requires", 'some permission')
          subclass.send("permissions_required_to_#{t}").
            should == Set.new(['some permission'])
        end

        it "can be changed in subclasses" do
          subclass = Class.new(model)
          model.send("#{t}_requires", 'some permission')
          subclass.send("#{t}_requires", 'another permission')
          subclass.send("permissions_required_to_#{t}").
            should == Set.new(['another permission'])
        end

        it "doesn't mess with superclass' value" do
          subclass = Class.new(model)
          model.send("#{t}_requires", 'some permission')
          subclass.send("#{t}_requires", 'another permission')
          subclass.send("permissions_required_to_#{t}").
            should == Set.new(['another permission'])
          model.send("permissions_required_to_#{t}").
            should == Set.new(['some permission'])
        end

        it "informs Registry about the permissions" do
          Registry.should_receive(:register).
            with('some permission',
                 :model => 'Record',
                 :action => t)
          model.send("#{t}_requires", 'some permission')
        end

      end

      describe "additional #{r}" do

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
          subclass = Class.new(model)
          model.send("#{t}_requires", 'some permission')
          subclass.send("add_#{t}_requirement", "another permission")
          subclass.send("permissions_required_to_#{t}").
            should == Set.new(['some permission', 'another permission'])
        end

        it "doesn't mess with superclass' value" do
          # Config is not taken into account because of the explicit
          # declaration.
          subclass = Class.new(model)
          model.send("#{t}_requires", 'some permission')
          subclass.send("add_#{t}_requirement", 'another permission')
          model.send("permissions_required_to_#{t}").
            should == Set.new(['some permission'])
        end

        it "combines permissions from superclasses and config" do
          config.stub("default_#{t}_permissions").
            and_return(Set.new(['permission one']))
          subclass = Class.new(model)
          model.send("add_#{t}_requirement", 'permission two')
          subclass.send("add_#{t}_requirement", 'permission three')
          subclass.send("permissions_required_to_#{t}").
            should == Set.new(['permission one', 'permission two',
                               'permission three'])
        end

        it "informs Registry about the permissions" do
          Registry.should_receive(:register).
            with('some permission',
                 :model => 'Record',
                 :action => t)
          model.send("add_#{t}_requirement", 'some permission')
        end

      end

    end
  end
end
