require 'spec_helper'

describe "role propagation on leaf" do
  include WithConstants

  let_constant(:user_class) do
    new_class(:User, ActiveRecord::Base) do
      include AccessControl::ActiveRecordSubject
    end
  end

  let(:user) { User.create! }
  let(:role) { AccessControl::Role.store(:name => "Role") }

  let_constant(:record_class) do
    new_class(:Record, ActiveRecord::Base) do
      include AccessControl::Securable

      attr_accessor :parent_record
      attr_accessor :child_record
      inherits_permissions_from :parent_record

      after_save do |record|
        if parent_record = record.parent_record
          parent_record.save! if parent_record.new_record?
        end

        if child_record = record.child_record
          child_record.parent_record = record
          child_record.save!
        end
      end

      requires_no_permissions!
    end
  end

  let(:parent_record) { record_class.new(:name => 'parent') }

  def node_of(record)
    AccessControl::Node(record)
  end

  describe "with parents which are already persisted at the time of saving" do
    before do
      parent_record.save!
      role.assign_to(user, parent_record)
    end

    context "on create" do
      let(:child_record) { record_class.new(:parent_record => parent_record) }

      context "when the record saves sucessfully" do
        before { child_record.save! }

        it "propagates roles" do
          role.should be_assigned_to(user, child_record)
        end
      end

      context "when the record fails to save" do
        before do
          record_class.class_eval do
            validate { |record| record.errors.add(:invalid, :name) }
          end
          child_record.save
        end

        it "doesn't propagate roles" do
          role.should_not be_assigned_to(user, child_record)
        end
      end
    end

    context "on update" do
      let(:child_record) { record_class.create! }

      before do
        child_record.parent_record = parent_record
      end

      context "when the record saves sucessfully" do
        before { child_record.save! }

        it "propagates roles" do
          role.should be_assigned_to(user, child_record)
        end
      end

      context "when the record fails to save" do
        before do
          record_class.class_eval do
            validate { |record| record.errors.add(:invalid, :name) }
          end
          child_record.save
        end

        it "doesn't propagate roles" do
          role.should_not be_assigned_to(user, child_record)
        end
      end
    end

    context "on destroy" do
      let(:child_record) do
        record_class.create!(:parent_record => parent_record)
      end

      context "when the record is destroyed" do
        before do
          child_record.destroy
        end

        it "depropagate the role" do
          role.should_not be_assigned_to(user, child_record)
        end
      end

      context "when the record fails to be destroyed" do
        before do
          record_class.class_eval { before_destroy { |record| false } }
          child_record.destroy
        end

        it "keeps the propagation" do
          role.should be_assigned_to(user, child_record)
        end
      end
    end
  end

  describe "with child records which are persisted when the parent is saved" do
    context "on create" do
      let(:child_record) { record_class.new }

      before do
        parent_record.child_record = child_record
      end

      context "when the record saves sucessfully" do
        before { parent_record.save! }

        it "propagates roles" do
          role.assign_to(user, parent_record)
          role.should be_assigned_to(user, child_record)
        end
      end

      context "when the record fails to save" do
        before do
          record_class.class_eval do
            validate { |record| record.errors.add(:invalid, :name) }
          end
          parent_record.save
        end

        it "doesn't propagate roles" do
          role.should_not be_assigned_to(user, child_record)
        end
      end
    end

    context "on update" do
      let(:child_record) { record_class.new }

      before do
        parent_record.save!
        parent_record.child_record = child_record
      end

      context "when the record saves sucessfully" do
        before do
          parent_record.save!
          role.assign_to(user, parent_record)
        end

        it "propagates roles" do
          role.should be_assigned_to(user, child_record)
        end
      end

      context "when the record fails to save" do
        before do
          record_class.class_eval do
            validate { |record| record.errors.add(:invalid, :name) }
          end
          parent_record.save
        end

        it "doesn't propagate roles" do
          role.should_not be_assigned_to(user, child_record)
        end
      end
    end

    context "on destroy" do
      let(:child_record) { record_class.new }

      before do
        parent_record.child_record = child_record
        parent_record.save!
        role.assign_to(user, parent_record)
      end

      context "when the record is destroyed" do
        before { parent_record.destroy }

        it "depropagate the role" do
          role.should_not be_assigned_to(user, child_record)
        end
      end

      context "when the record fails to be destroyed" do
        before do
          record_class.class_eval { before_destroy { |record| false } }
          parent_record.destroy
        end

        it "keeps the propagation" do
          role.should be_assigned_to(user, child_record)
        end
      end
    end
  end

  describe "with parents which are persisted along with the target record" do
    context "on create" do
      let(:child_record) { record_class.new(:parent_record => parent_record) }

      before do
        child_record.save!
        role.assign_to(user, parent_record)
      end

      it "allows role propagation" do
        role.should be_assigned_to(user, child_record)
      end
    end

    context "on update" do
      let(:child_record) { record_class.create! }

      before do
        child_record.parent_record = parent_record
      end

      it "allows role propagation" do
        child_record.save!
        role.assign_to(user, parent_record)
        role.should be_assigned_to(user, child_record)
      end
    end
  end
end
