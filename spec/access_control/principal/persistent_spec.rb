require 'spec_helper'

module AccessControl
  class Principal
    describe Persistent do
      it "can be created with valid attributes" do
        Persistent.create!(:subject_type => 'SubjectType', :subject_id => 1)
      end
    end
  end
end
