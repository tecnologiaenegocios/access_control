require 'spec_helper'

module AccessControl
  module ORM
    describe SequelClass do
      include WithConstants
      let_constant(:model) { new_class(:Record, Sequel::Model(:records)) }
      let_constant(:stimodel) do
        new_class(:STIRecord, Sequel::Model(:sti_records)) do
          plugin :single_table_inheritance, :type
        end
      end
      let_constant(:sub_stimodel) { new_class(:SubSTIRecord, stimodel) }

      let(:orm)        { SequelClass.new(model) }
      let(:stiorm)     { SequelClass.new(stimodel) }
      let(:sub_stiorm) { SequelClass.new(sub_stimodel) }

      it_should_behave_like "an ORM adapter"
    end
  end
end
