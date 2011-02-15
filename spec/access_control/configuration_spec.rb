require 'spec_helper'

module AccessControl
  describe Configuration do

    { "view permission" => 'view',
      "query permission" => 'query'}.each do |k, v|

      it "can define a default #{v} permissions" do
        Configuration.new.send(
          "default_#{v}_permissions=",
          'some permission'
        )
      end

      it "can retrieve the query permission" do
        config = Configuration.new
        config.send("default_#{v}_permissions=", 'some permission')
        config.send("default_#{v}_permissions").should == 'some permission'
      end

      it "defaults to '#{v}'" do
        Configuration.new.send("default_#{v}_permissions").should == [v]
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
