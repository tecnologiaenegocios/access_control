require 'spec_helper'
require 'access_control/active_record_subject'

module AccessControl
  describe ActiveRecordSubject do
    # A Mix-in module for User-like ActiveRecord models.

    let(:base)  { Class.new }
    let(:model) { Class.new(base) }

    before do
      base.stub(:after_create)
      base.stub(:has_one)
    end

    it "includes associator" do
      model.send(:include, ActiveRecordSubject)
      model.should include(ActiveRecordAssociator)
    end

    it "configures an association for Principal" do
      Principal.should_receive(:name).and_return("Principal's class name")
      model.should_receive(:associate_with_access_control).
        with(:ac_principal, "Principal's class name", :subject)
      model.send(:include, ActiveRecordSubject)
    end

  end
end
