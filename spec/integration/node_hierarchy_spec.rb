require 'spec_helper'

describe "node hierarchy" do
  include WithConstants

  let_constant(:user_class) do
    new_class(:User, ActiveRecord::Base) do
      include AccessControl::ActiveRecordSubject
    end
  end

  let(:user) { User.create! }
  let(:role) { AccessControl::Role.store(:name => "Role") }

  describe "with parents which are persisted along with the target record" do
    let_constant(:record_class) do
      new_class(:Record, ActiveRecord::Base) do
        include AccessControl::Securable

        attr_accessor :parent_record
        inherits_permissions_from :parent_record

        after_save do |record|
          if parent_record = record.parent_record
            parent_record.save!
          end
        end

        requires_no_permissions!
      end
    end

    let(:parent_record) { record_class.new(:name => 'parent') }

    def node_of(record)
      AccessControl::Node(record)
    end

    context "on create" do
      let(:child_record)  { record_class.new(:parent_record => parent_record) }

      context "when the record saves successfully" do
        it "persists the nodes" do
          child_record.save!
          node_of(child_record).should be_persisted
          node_of(parent_record).should be_persisted
        end

        it "allows role propagation" do
          child_record.save!
          role.assign_to(user, parent_record)
          role.should be_assigned_to(user, child_record)
        end

        it "returns the result of regular #save" do
          child_record.save.should be_true
        end
      end

      context "when the record fails to save" do
        before do
          record_class.class_eval do
            validate do |record|
              record.errors.add(:invalid, :name)
            end
          end
        end

        it "doesn't create nodes" do
          child_record.save
          node_of(child_record).should_not be_persisted
          node_of(parent_record).should_not be_persisted
        end

        it "returns the result of regular #save" do
          child_record.save.should be_false
        end
      end
    end

    context "on update" do
      let(:child_record)  { record_class.create! }

      before do
        child_record.parent_record = parent_record
      end

      context "when the record saves successfully" do
        it "creates the node of the parent record" do
          child_record.save!
          node_of(parent_record).should be_persisted
        end

        it "allows role propagation" do
          child_record.save!
          role.assign_to(user, parent_record)
          role.should be_assigned_to(user, child_record)
        end

        it "returns the result of regular #save" do
          child_record.save.should be_true
        end
      end

      context "when the record fails to save" do
        before do
          record_class.class_eval do
            validate do |record|
              record.errors.add(:invalid, :name)
            end
          end
        end

        it "doesn't create the parent node" do
          child_record.save
          node_of(parent_record).should_not be_persisted
        end

        it "returns the result of regular #save" do
          child_record.save.should be_false
        end
      end
    end

    context "on destroy" do
      let(:child_record)  { record_class.create! }

      context "when the record is destroyed" do
        it "removes the node" do
          child_node = node_of(child_record)
          child_record.destroy

          AccessControl::Node.has?(child_node.id).should be_false
        end
      end

      context "when the record fails to be destroyed" do
        before do
          record_class.class_eval do
            before_destroy do |record|
              false
            end
          end
        end

        it "keeps the node" do
          child_record.destroy
          node_of(child_record).should be_persisted
        end
      end
    end
  end
end
