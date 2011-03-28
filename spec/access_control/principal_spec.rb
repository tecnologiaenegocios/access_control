require 'spec_helper'

module AccessControl
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

    describe "anonymous principal" do

      let(:anonymous_principal) do
        anonymous_subject_type = Principal.anonymous_subject_type
        anonymous_subject_id = Principal.anonymous_subject_id
        Principal.find_by_subject_type_and_subject_id(
          anonymous_subject_type, anonymous_subject_id
        )
      end

      it "creates the anonymous principal" do
        Principal.create_anonymous_principal!
      end

      it "can return the anonymous principal object" do
        Principal.create_anonymous_principal!
        Principal.anonymous.should == anonymous_principal
      end

      it "can return the anonymous principal id" do
        Principal.create_anonymous_principal!
        Principal.anonymous_id.should == anonymous_principal.id
      end

      it "returns nil if there's no anonymous principal" do
        Principal.anonymous.should be_nil
      end

      describe "predicate method #anonymous?" do

        it "returns true if the principal is the anonymous principal" do
          Principal.create_anonymous_principal!
          Principal.anonymous.anonymous?.should be_true
        end

        it "returns false otherwise" do
          principal = Principal.create!(:subject => stub_model(SubjectObj))
          principal.anonymous?.should be_false
        end

      end

    end

  end
end
