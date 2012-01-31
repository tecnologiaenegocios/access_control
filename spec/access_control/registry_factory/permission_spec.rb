require 'spec_helper'

module AccessControl; class RegistryFactory;
  describe Permission do

    it "has a name" do
      permission = Permission.new
      permission.name.should == ''
    end

    it "can have its name set on initialization" do
      permission = Permission.new('foo')
      permission.name.should == 'foo'
    end

    it "responds to :ac_methods and returns an empty set by default" do
      permission = Permission.new
      permission.ac_methods.should == Set.new
    end

    it "responds to :context_designator and returns an empty hash by default" do
      permission = Permission.new
      permission.context_designator.should == {}
    end

  end
end; end
