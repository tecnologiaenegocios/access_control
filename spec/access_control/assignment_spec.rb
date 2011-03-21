require 'spec_helper'

module AccessControl
  describe Assignment do
    it "can be created with valid attributes" do
      Assignment.create!(
        :node => stub_model(AccessControl::Node),
        :principal => stub_model(AccessControl::Principal),
        :role => stub_model(AccessControl::Role)
      )
    end
    it "cannot be wrapped by a security proxy" do
      Assignment.securable?.should be_false
    end
  end
end
