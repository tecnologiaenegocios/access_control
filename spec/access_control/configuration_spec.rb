require 'spec_helper'

module AccessControl
  describe Configuration do

    {
      "view" => 'view',
      "query" => 'query',
      "create" => 'add',
      "update" => 'modify',
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

      it "defaults to '#{k}'" do
        Configuration.new.send("default_#{k}_permissions").
          should == Set.new([v])
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
