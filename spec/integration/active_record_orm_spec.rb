require 'spec_helper'

module AccessControl
  module ORM
    describe ActiveRecordClass do
      include WithConstants
      let_constant(:model)        { new_class(:Record,    ActiveRecord::Base) }
      let_constant(:stimodel)     { new_class(:STIRecord, ActiveRecord::Base) }
      let_constant(:sub_stimodel) { new_class(:SubSTIRecord, stimodel) }

      let(:orm)        { ActiveRecordClass.new(model) }
      let(:stiorm)     { ActiveRecordClass.new(stimodel) }
      let(:sub_stiorm) { ActiveRecordClass.new(sub_stimodel) }

      it_should_behave_like "an ORM adapter"
    end
  end
end
