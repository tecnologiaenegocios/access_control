require 'spec_helper'
require 'access_control/securable'

module AccessControl
  describe Securable do

    let(:model) { Class.new }

    before do
      model.send(:include, Securable)
    end

    it "includes Declarations" do
      model.should include(Declarations)
    end

    it "includes MethodProtection" do
      model.should include(MethodProtection)
    end

    describe "with active record models" do

      let(:model) { Class.new(ActiveRecord::Base) }

      before do
        model.stub(:has_one)
      end

      it "includes ActiveRecordSecurable" do
        model.should include(ActiveRecordSecurable)
      end

      it "includes Inheritance" do
        model.should include(Inheritance)
      end

      it "includes ModelSecurity" do
        model.should include(ModelSecurity)
      end

      it "includes Restriction" do
        model.should include(Restriction)
      end

    end

  end
end
