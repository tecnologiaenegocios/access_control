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
      let_constant(:sub_sub_stimodel) { new_class(:SubSubSTIRecord, sub_stimodel) }

      let_constant(:fake_stimodel) do
        new_class(:FakeSTIRecord, Sequel::Model(:sti_records))
      end

      let(:orm)            { SequelClass.new(model) }
      let(:stiorm)         { SequelClass.new(stimodel) }
      let(:sub_stiorm)     { SequelClass.new(sub_stimodel) }
      let(:sub_sub_stiorm) { SequelClass.new(sub_sub_stimodel) }
      let(:fake_stiorm)    { SequelClass.new(fake_stimodel) }

      def select_all(orm, subclasses: false)
        AccessControl.db[orm.table_name].
          select(orm.pk_name).
          filter("`#{orm.pk_name}` IN (#{orm.all_sql(subclasses: subclasses)})").
          select_map(orm.pk_name)
      end

      it_should_behave_like "an ORM adapter"
    end
  end
end
