require 'spec_helper'

module AccessControl
  module ORM
    describe Base do
      let(:orm_class) { Class.new(Base).new }

      describe Base.instance_method(:name).name do
        before  { orm_class.stub(:object => stub(:name => 'ModelName')) }
        subject { orm_class.name }

        it { should == :ModelName }
      end

      describe Base.instance_method(:new).name do
        let(:instance) { stub }
        before         { orm_class.stub(:object => stub(:new => instance)) }
        subject        { orm_class.new }

        it { should be instance }
      end
    end
  end
end
