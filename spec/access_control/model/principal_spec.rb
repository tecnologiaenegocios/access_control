require 'spec_helper'

module AccessControl::Model
  describe Principal do

    before do
      class Object::SubjectObj < ActiveRecord::Base
        def self.columns
          []
        end
      end
    end

    after do
      Object.send(:remove_const, 'SubjectObj')
    end

    it "can be created with valid attributes" do
      Principal.create!(:subject => stub_model(SubjectObj))
    end

    it "cannot be wrapped by a security proxy" do
      Principal.securable?.should be_false
    end

  end
end
