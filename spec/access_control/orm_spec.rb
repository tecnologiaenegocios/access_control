require 'spec_helper'

module AccessControl
  module ORM
    describe Base do
      let(:orm_class) { Class.new(Base).new }

      describe ".name" do
        before  { orm_class.stub(:object => stub(:name => 'ModelName')) }
        subject { orm_class.name }

        it { should == "ModelName" }
      end

      describe ".new" do
        let(:instance) { stub }
        before         { orm_class.stub(:object => stub(:new => instance)) }
        subject        { orm_class.new }

        it { should be instance }
      end

      describe ".pk_of" do
        let(:instance) { stub(:pk => 'the primary key of this instance') }
        before  { orm_class.stub(:pk_name).and_return(:pk) }
        subject { orm_class.pk_of(instance) }

        it { should == instance.pk }
      end
    end

    describe ".adapt_class" do
      context "when the argument is an ActiveRecord model" do
        let(:ar_model) { ActiveRecord::Base }

        it "wraps it into an ActiveRecordClass" do
          return_value = ORM.adapt_class(ar_model)
          return_value.should be_an_instance_of(ActiveRecordClass)
        end
      end

      context "when the argument is a Sequel model" do
        let(:ar_model) { Sequel::Model }

        it "wraps it into an SequelClass" do
          return_value = ORM.adapt_class(ar_model)
          return_value.should be_an_instance_of(SequelClass)
        end
      end
    end
  end
end
