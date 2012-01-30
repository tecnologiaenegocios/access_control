require 'spec_helper'

module AccessControl; class RegistryFactory;
  describe Permission do

    it "has a name" do
      permission = Permission.new
      permission.name.should == ''
    end

    it "can have its name set" do
      permission = Permission.new
      permission.name = 'foo'
      permission.name.should == 'foo'
    end

    it "can have its name set on initialization" do
      permission = Permission.new('foo')
      permission.name.should == 'foo'
    end

    it "responds to :controller_action and returns nil by default" do
      permission = Permission.new
      permission.controller_action.should be_nil
    end

    it "has an empty hash as a default value for :ac_context" do
      permission = Permission.new
      permission.ac_context.should == {}
    end

  end
end; end
