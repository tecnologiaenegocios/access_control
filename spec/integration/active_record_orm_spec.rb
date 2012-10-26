require 'spec_helper'

module AccessControl
  module ORM
    describe ActiveRecordClass do
      include WithConstants
      let_constant(:model)         { new_class(:Record,       ActiveRecord::Base) }
      let_constant(:stimodel)      { new_class(:STIRecord,    ActiveRecord::Base) }
      let_constant(:sub_stimodel)  { new_class(:SubSTIRecord, stimodel) }

      let_constant(:fake_stimodel) do
        new_class(:FakeSTIRecord, ActiveRecord::Base) do
          set_table_name :sti_records
          self.inheritance_column = nil
        end
      end

      let(:orm)         { ActiveRecordClass.new(model) }
      let(:stiorm)      { ActiveRecordClass.new(stimodel) }
      let(:sub_stiorm)  { ActiveRecordClass.new(sub_stimodel) }
      let(:fake_stiorm) { ActiveRecordClass.new(fake_stimodel) }

      def select_sti_subquery(orm)
        ActiveRecord::Base.connection.execute(orm.sti_subquery).map do |r|
          r[0]
        end
      end

      it_should_behave_like "an ORM adapter"
    end
  end
end
