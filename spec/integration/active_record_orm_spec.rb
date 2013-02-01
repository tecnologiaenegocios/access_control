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

      let_constant(:default_scoped_model) do
        new_class(:DefaultScopedModel, ActiveRecord::Base) do
          set_table_name :records
          belongs_to(
            :sti_record,
            :foreign_key => 'record_id',
            :class_name => 'STIRecord'
          )
          default_scope(:include => :sti_record,
                        :order => 'sti_records.name')
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

      describe ".sti_subquery in default-scoped models" do
        let(:orm) { ActiveRecordClass.new(default_scoped_model) }

        let(:record1)     { orm.new.tap { |r| orm.persist(r) } }
        let(:record2)     { orm.new.tap { |r| orm.persist(r) } }
        let(:record3)     { orm.new.tap { |r| orm.persist(r) } }
        let!(:record_ids) { [record1.id, record2.id, record3.id] }

        specify do
          select_sti_subquery(orm).should include_only(*record_ids)
        end
      end
    end
  end
end
