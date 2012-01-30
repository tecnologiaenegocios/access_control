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

    it "can have arbitrary attributes set" do
      permission = Permission.new
      permission.attribute = ['a', 'value']
      permission.attribute.should == ['a', 'value']
    end

  end
end; end
