require 'spec_helper'

module AccessControl
  module Model
    describe Assignment do
      it "can be created with valid attributes" do
        Assignment.create!(
          :node => stub_model(AccessControl::Model::Node),
          :principal => stub_model(AccessControl::Model::Principal),
          :role => stub_model(AccessControl::Model::Role)
        )
      end
      it "cannot be wrapped by a security proxy" do
        Assignment.securable?.should be_false
      end
    end
  end
end
