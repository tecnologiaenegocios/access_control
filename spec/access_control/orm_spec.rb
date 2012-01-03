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
    end
  end
end
