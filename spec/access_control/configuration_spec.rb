require 'spec_helper'

module AccessControl
  describe Configuration do

    it "can define a default query permissions" do
      Configuration.new.default_query_permissions = 'some permission'
    end

    it "can retrieve the query permission" do
      config = Configuration.new
      config.default_query_permissions = 'some permission'
      config.default_query_permissions.should == 'some permission'
    end

    it "defaults to 'query'" do
      Configuration.new.default_query_permissions.should == ['query']
    end

  end

  describe "configuration API" do

    describe "#configure" do
      it "yields a Configuration object" do
        AccessControl.configure do |config|
          config.is_a?(Configuration).should be_true
        end
      end
      it "yields a new configuration object every time" do
        first = second = nil
        AccessControl.configure{|config| first = config}
        AccessControl.configure{|config| seconf = config}
        first.should_not equal(second)
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
