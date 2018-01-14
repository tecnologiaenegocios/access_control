require 'spec_helper'

describe "association unrestriction" do
  include WithConstants

  before do
    role.globally_assign_to(user)
    AccessControl.manager.current_subjects = [user]
  end

  after do
    AccessControl.no_manager
    AccessControl.reset
    AccessControl::PermissionInspector.clear_role_cache
  end

  let(:user) { User.create! }
  let(:role) { AccessControl::Role.store(name: 'global') }

  let_constant(:user_class) do
    new_class(:User, ActiveRecord::Base) do
      include AccessControl::ActiveRecordSubject
    end
  end

  let_constant(:record_class) do
    new_class(:Record, ActiveRecord::Base) do
      include AccessControl::Securable
      requires_no_permissions!
    end
  end

  let_constant(:associated_record_class) do
    new_class(:AssociatedRecord, ActiveRecord::Base) do
      include AccessControl::Securable

      list_requires 'list_associated_record'
      show_requires 'show_associated_record'
      create_requires nil
      update_requires nil
      destroy_requires nil
    end
  end

  shared_examples_for "single record association" do
    let(:associated_record) { AssociatedRecord.create! }
    let(:record) { Record.create!(associated_record: associated_record) }
    let(:fresh_record) { Record.find(record.id) }

    describe "associated unpermitted record" do
      it "should be returned when eager loaded in single query" do
        result = Record.find(
          :all,
          include: :associated_record,
          conditions: { id: record.id },
          # Referencing associations in conditions or orders triggers single
          # JOIN-based query.
          order: 'sti_records.id, records.id'
        ).first

        association = result.instance_variable_get(:@associated_record)
        association.target.should == associated_record
      end

      it "should be returned when eager loaded in additional query" do
        result = Record.find(
          :all,
          include: :associated_record,
          conditions: { id: record.id },
        ).first

        association = result.instance_variable_get(:@associated_record)
        association.target.should == associated_record
      end

      it "should be returned when accessed without eager loading" do
        fresh_record.associated_record.should == associated_record
      end

      it "should be returned if reload is forced" do
        fresh_record.associated_record(true).should == associated_record
      end

      it "should not be returned if restriction is explicitly required" do
        fresh_record.restricted_associated_record.should be_nil
      end
    end
  end

  shared_examples_for "collection association" do
    let(:associated_record) { AssociatedRecord.create! }
    let(:record) { Record.create!(associated_records: [associated_record]) }
    let(:fresh_record) { Record.find(record.id) }

    describe "associated unpermitted record" do
      it "should be returned when eager loaded in single query" do
        result = Record.find(
          :all,
          include: :associated_records,
          conditions: { id: record.id },
          # Referencing associations in conditions or orders triggers single
          # JOIN-based query.
          order: 'sti_records.id, records.id'
        ).first

        association = result.instance_variable_get(:@associated_records)
        association.target.first.should == associated_record
      end

      it "should be returned when eager loaded in additional query" do
        result = Record.find(
          :all,
          include: :associated_records,
          conditions: { id: record.id },
        ).first

        association = result.instance_variable_get(:@associated_records)
        association.target.first.should == associated_record
      end

      it "should be returned for #first" do
        fresh_record.associated_records.first.should == associated_record
      end

      it "should be returned for #first on ad-hoc scope" do
        fresh_record.associated_records.scoped({}).first.should == associated_record
      end

      it "should be returned for #first on class-method scope" do
        fresh_record.associated_records.class_method_scope.first.should == associated_record
      end

      it "should be returned for #first on named scope" do
        fresh_record.associated_records.named_scope.first.should == associated_record
      end

      it "should be returned for #last" do
        fresh_record.associated_records.last.should == associated_record
      end

      it "should be returned for #last on ad-hoc scope" do
        fresh_record.associated_records.scoped({}).last.should == associated_record
      end

      it "should be returned for #last on class-method scope" do
        fresh_record.associated_records.class_method_scope.last.should == associated_record
      end

      it "should be returned for #last on named scope" do
        fresh_record.associated_records.named_scope.last.should == associated_record
      end

      it "should be returned for #all" do
        fresh_record.associated_records.all.first.should == associated_record
      end

      it "should be returned for #all on ad-hoc scope" do
        fresh_record.associated_records.scoped({}).all.first.should == associated_record
      end

      it "should be returned for #all on class-method scope" do
        fresh_record.associated_records.class_method_scope.all.first.should == associated_record
      end

      it "should be returned for #all on named scope" do
        fresh_record.associated_records.named_scope.all.first.should == associated_record
      end

      it "should be returned for #find(:first)" do
        fresh_record.associated_records.find(:first).should == associated_record
      end

      it "should be returned for #find(:first) on ad-hoc scope" do
        fresh_record.associated_records.scoped({}).find(:first).should == associated_record
      end

      it "should be returned for #find(:first) on class-method scope" do
        fresh_record.associated_records.class_method_scope.find(:first).should == associated_record
      end

      it "should be returned for #find(:first) on named scope" do
        fresh_record.associated_records.named_scope.find(:first).should == associated_record
      end

      it "should be returned for #find(:last)" do
        fresh_record.associated_records.find(:last).should == associated_record
      end

      it "should be returned for #find(:last) on ad-hoc scope" do
        fresh_record.associated_records.scoped({}).find(:last).should == associated_record
      end

      it "should be returned for #find(:last) on class-method scope" do
        fresh_record.associated_records.class_method_scope.find(:last).should == associated_record
      end

      it "should be returned for #find(:last) on named scope" do
        fresh_record.associated_records.named_scope.find(:last).should == associated_record
      end

      it "should be returned for #find(:all)" do
        fresh_record.associated_records.find(:all).first.should == associated_record
      end

      it "should be returned for #find(:all) on ad-hoc scope" do
        fresh_record.associated_records.scoped({}).find(:all).first.should == associated_record
      end

      it "should be returned for #find(:all) on class-method scope" do
        fresh_record.associated_records.class_method_scope.find(:all).first.should == associated_record
      end

      it "should be returned for #find(:all) on named scope" do
        fresh_record.associated_records.named_scope.find(:all).first.should == associated_record
      end

      it "should be returned if reload is forced" do
        fresh_record.associated_records(true).first.should == associated_record
      end

      it "should be counted" do
        fresh_record.associated_records.count.should == 1
      end

      it "should not be returned if restriction is explicitly required" do
        fresh_record.restricted_associated_records.first.should be_nil
      end

      it "should not be counted if restriction is explicitly required" do
        fresh_record.restricted_associated_records.count.should == 0
      end
    end
  end

  describe "on belongs_to:" do
    before do
      AssociatedRecord.class_eval do
        set_table_name :sti_records
        self.inheritance_column = '' # skip STI, we don't use it here.
      end

      Record.class_eval do
        set_table_name :records
        belongs_to :associated_record, foreign_key: :record_id
      end
    end

    it_should_behave_like "single record association"
  end

  describe "on has_one:" do
    before do
      AssociatedRecord.class_eval do
        set_table_name :records
      end

      Record.class_eval do
        set_table_name :sti_records
        self.inheritance_column = '' # skip STI, we don't use it here.
        has_one :associated_record, foreign_key: :record_id, autosave: true
      end
    end

    it_should_behave_like "single record association"
  end

  describe "on has_many:" do
    before do
      AssociatedRecord.class_eval do
        set_table_name :records
        named_scope :named_scope, {}
        def self.class_method_scope
          scoped({})
        end
      end

      Record.class_eval do
        set_table_name :sti_records
        self.inheritance_column = '' # skip STI, we don't use it here.
        has_many :associated_records, foreign_key: :record_id, autosave: true
      end
    end

    it_should_behave_like "collection association"
  end

  describe "on has_and_belongs_to_many:" do
    before do
      AssociatedRecord.class_eval do
        set_table_name :sti_records
        self.inheritance_column = '' # skip STI, we don't use it here.
        named_scope :named_scope, {}
        def self.class_method_scope
          scoped({})
        end
      end

      Record.class_eval do
        set_table_name :records
        has_and_belongs_to_many :associated_records,
          join_table: :records_records,
          foreign_key: :from_id,
          association_foreign_key: :to_id,
          autosave: true
      end
    end

    it_should_behave_like "collection association"
  end
end
