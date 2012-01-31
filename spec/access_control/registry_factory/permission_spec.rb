require 'spec_helper'

module AccessControl; class RegistryFactory;
  describe Permission do

    subject { Permission.new }

    it "has a name" do
      subject.name.should == ''
    end

    it "can have its name set on initialization" do
      permission = Permission.new('foo')
      permission.name.should == 'foo'
    end

    it "responds to :ac_methods and returns an empty set by default" do
      subject.ac_methods.should == Set.new
    end

    it "can have its :ac_methods modified" do
      subject.ac_methods << 'foo'
      subject.ac_methods.should include('foo')
    end

    it "responds to :ac_classes and returns an empty set by default" do
      subject.ac_classes.should == Set.new
    end

    it "can have its :ac_classes modified" do
      subject.ac_classes << 'foo'
      subject.ac_classes.should include('foo')
    end

    it "responds to :context_designator and returns an empty hash by default" do
      subject.context_designator.should == {}
    end

    it "can have its :context_designator modified" do
      subject.context_designator['foo'] = 'bar'
      subject.context_designator['foo'].should == 'bar'
    end

  end
end; end
