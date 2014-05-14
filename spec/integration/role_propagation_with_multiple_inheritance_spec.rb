require 'spec_helper'

describe "role propagation with multiple inheritance" do
  include WithConstants

  let_constant(:user_class) do
    new_class(:User, ActiveRecord::Base) do
      include AccessControl::ActiveRecordSubject
    end
  end

  let(:user) { User.create! }
  let(:role1) { AccessControl::Role.store(:name => "Role1") }
  let(:role2) { AccessControl::Role.store(:name => "Role2") }

  describe "on diamong-like shapes" do
    let_constant(:record_class) do
      new_class(:Record, ActiveRecord::Base) do
        include AccessControl::Securable

        attr_accessor :parent_records
        inherits_permissions_from :parent_records

        requires_no_permissions!
      end
    end

    let(:top_level) { record_class.create! }
    let(:middle_level_1) { record_class.create!(parent_records: [top_level]) }
    let(:middle_level_2) { record_class.create!(parent_records: [top_level]) }
    let!(:bottom_level) {
      record_class.create!(parent_records: [middle_level_1, middle_level_2])
    }

    context "when a role is assigned at the top-level record" do
      before do
        role1.assign_to(user, top_level)
      end

      it "is inherited in the whole graph" do
        role1.should be_assigned_to(user, middle_level_1)
        role1.should be_assigned_to(user, middle_level_2)
        role1.should be_assigned_to(user, bottom_level)
      end

      context "and later the role is unassigned" do
        before do
          role1.unassign_from(user, top_level)
        end

        it "is unassigned at the whole graph" do
          role1.should_not be_assigned_to(user, middle_level_1)
          role1.should_not be_assigned_to(user, middle_level_2)
          role1.should_not be_assigned_to(user, bottom_level)
        end
      end
    end

    context "when different roles are given in the middle of the graph" do
      before do
        role1.assign_to(user, middle_level_1)
        role2.assign_to(user, middle_level_2)
      end

      context "the bottom-level record" do
        subject { bottom_level }

        it "inherits all" do
          role1.should be_assigned_to(user, subject)
          role2.should be_assigned_to(user, subject)
        end
      end

      context "and later one of them is unassigned" do
        before do
          role1.unassign_from(user, middle_level_1)
        end

        context "the bottom-level record" do
          subject { bottom_level }

          it "is not inherited anymore, but the others are kept" do
            role1.should_not be_assigned_to(user, subject)
            role2.should be_assigned_to(user, subject)
          end
        end
      end
    end

    context "when a role is given in the top level" do
      before do
        role1.assign_to(user, top_level)
      end

      context "and another is given in one of the middle-level records" do
        before do
          role2.assign_to(user, middle_level_2)
        end

        context "the bottom record" do
          subject { bottom_level }

          it "inherits both" do
            role1.should be_assigned_to(user, subject)
            role2.should be_assigned_to(user, subject)
          end
        end

        context "and the other middle-level record is removed" do
          before do
            middle_level_1.destroy
          end

          context "the bottom record" do
            subject { bottom_level }

            it "inherits both due to the multiple inheritance" do
              role1.should be_assigned_to(user, subject)
              role2.should be_assigned_to(user, subject)
            end
          end
        end

        context "and that middle-level record is removed" do
          before do
            middle_level_2.destroy
          end

          context "the bottom record" do
            subject { bottom_level }

            it "inherits only the top-level role" do
              role1.should be_assigned_to(user, subject)
              role2.should_not be_assigned_to(user, subject)
            end
          end
        end
      end
    end
  end

  describe "direct cycle" do
    let_constant(:record_class) do
      new_class(:Record, ActiveRecord::Base) do
        include AccessControl::Securable

        has_and_belongs_to_many(
          :parent_records,
          class_name: "Record",
          join_table: :records_records,
          foreign_key: :to_id,
          association_foreign_key: :from_id
        )
        has_and_belongs_to_many(
          :child_records,
          class_name: "Record",
          join_table: :records_records,
          foreign_key: :from_id,
          association_foreign_key: :to_id
        )

        inherits_permissions_from :parent_records

        requires_no_permissions!
      end
    end

    let(:top_level) { record_class.create! }
    let(:middle_level_1) { record_class.create!(parent_records: [top_level]) }
    let(:middle_level_2) { record_class.create!(parent_records: [top_level]) }
    let(:bottom_level_1) {
      record_class.create!(parent_records: [middle_level_1])
    }
    let!(:bottom_level_2) {
      record_class.create!(parent_records: [middle_level_2, bottom_level_1])
    }

    before do
      bottom_level_1.parent_records << bottom_level_2
      AccessControl.refresh_parents_of(bottom_level_1)
    end

    context "when a role is assigned at the top-level record" do
      before do
        role1.assign_to(user, top_level)
      end

      it "is inherited in the whole graph" do
        role1.should be_assigned_to(user, middle_level_1)
        role1.should be_assigned_to(user, middle_level_2)
        role1.should be_assigned_to(user, bottom_level_1)
        role1.should be_assigned_to(user, bottom_level_2)
      end

      context "and later the role is unassigned" do
        before do
          role1.unassign_from(user, top_level)
        end

        it "is unassigned at the whole graph" do
          role1.should_not be_assigned_to(user, middle_level_1)
          role1.should_not be_assigned_to(user, middle_level_2)
          role1.should_not be_assigned_to(user, bottom_level_1)
          role1.should_not be_assigned_to(user, bottom_level_2)
        end
      end

      context "and the same role is assigned in a bottom level record" do
        before do
          role1.assign_to(user, bottom_level_1)
        end

        context "each bottom level record" do
          it "inherits the role" do
            role1.should be_assigned_to(user, bottom_level_1)
            role1.should be_assigned_to(user, bottom_level_2)
          end
        end

        context "and later this assignment is undone" do
          before do
            role1.unassign_from(user, bottom_level_1)
          end

          context "each bottom level record" do
            it "inherits the role from top level due to the cycle" do
              role1.should be_assigned_to(user, bottom_level_1)
              role1.should be_assigned_to(user, bottom_level_2)
            end
          end
        end
      end

      context "and another role is assigned in a bottom level record" do
        before do
          role2.assign_to(user, bottom_level_2)
        end

        context "each bottom level record" do
          it "inherits both" do
            role1.should be_assigned_to(user, bottom_level_1)
            role1.should be_assigned_to(user, bottom_level_2)
            role2.should be_assigned_to(user, bottom_level_1)
            role2.should be_assigned_to(user, bottom_level_2)
          end
        end

        context "and later this assignment is undone" do
          before do
            role2.unassign_from(user, bottom_level_2)
          end

          context "each bottom level record" do
            it "inherits the role from top level due to the cycle" do
              role1.should be_assigned_to(user, bottom_level_1)
              role1.should be_assigned_to(user, bottom_level_2)
            end
          end
        end
      end
    end

    context "when different roles are given in the middle of the graph" do
      before do
        role1.assign_to(user, middle_level_1)
        role2.assign_to(user, middle_level_2)
      end

      context "each bottom level record" do
        it "inherits those which branch from their middle-level parents" do
          role1.should be_assigned_to(user, bottom_level_1)
          role2.should be_assigned_to(user, bottom_level_2)
        end

        it "inherits those which branch from their bottom-level parents" do
          role1.should be_assigned_to(user, bottom_level_2)
          role2.should be_assigned_to(user, bottom_level_1)
        end
      end

      context "and later one of them is unassigned" do
        before do
          role1.unassign_from(user, middle_level_1)
        end

        context "each bottom level record" do
          it "loose that role" do
            role1.should_not be_assigned_to(user, bottom_level_1)
            role1.should_not be_assigned_to(user, bottom_level_2)
          end

          it "inherits those which branch from their bottom-level parents" do
            role2.should be_assigned_to(user, bottom_level_1)
            role2.should be_assigned_to(user, bottom_level_2)
          end
        end
      end
    end

    context "when different roles are given in all middle records" do
      before do
        role1.assign_to(user, middle_level_1)
        role1.assign_to(user, middle_level_2)
        role2.assign_to(user, middle_level_1)
        role2.assign_to(user, middle_level_2)
      end

      context "each bottom level record" do
        it "inherits all" do
          role1.should be_assigned_to(user, bottom_level_1)
          role1.should be_assigned_to(user, bottom_level_2)
          role2.should be_assigned_to(user, bottom_level_1)
          role2.should be_assigned_to(user, bottom_level_2)
        end
      end

      context "and later one of the records loose its assigments" do
        before do
          role1.unassign_from(user, middle_level_1)
          role2.unassign_from(user, middle_level_1)
        end

        context "the bottom level record below the middle record assigned" do
          it "inherits their roles" do
            role1.should be_assigned_to(user, bottom_level_2)
            role2.should be_assigned_to(user, bottom_level_2)
          end
        end

        context "the bottom level record below the middle record unassigned" do
          it "inherits their roles from the bottom parent" do
            role1.should be_assigned_to(user, bottom_level_1)
            role2.should be_assigned_to(user, bottom_level_1)
          end
        end
      end
    end

    context "when a role is given in a bottom level record" do
      before do
        role1.assign_to(user, bottom_level_1)
      end

      context "each bottom level record" do
        it "inhreits the role due to the cycle or owns the role" do
          role1.should be_assigned_to(user, bottom_level_1)
          role1.should be_assigned_to(user, bottom_level_2)
        end
      end

      context "and later is removed" do
        before do
          role1.unassign_from(user, bottom_level_1)
        end

        context "each bottom record" do
          it "loose the role" do
            role1.should_not be_assigned_to(user, bottom_level_1)
            role1.should_not be_assigned_to(user, bottom_level_2)
          end
        end
      end
    end

    context "when a role is given in the top level" do
      before do
        role1.assign_to(user, top_level)
      end

      context "and another is given in one of the middle-level records" do
        before do
          role2.assign_to(user, middle_level_2)
        end

        context "each bottom level record" do
          it "inherits both" do
            role1.should be_assigned_to(user, bottom_level_1)
            role2.should be_assigned_to(user, bottom_level_1)
            role1.should be_assigned_to(user, bottom_level_2)
            role2.should be_assigned_to(user, bottom_level_2)
          end
        end

        context "and the other middle-level record is removed" do
          before do
            middle_level_1.destroy
          end

          context "each bottom record" do
            it "inherits both, due to the cycle" do
              role1.should be_assigned_to(user, bottom_level_1)
              role2.should be_assigned_to(user, bottom_level_1)
              role1.should be_assigned_to(user, bottom_level_2)
              role2.should be_assigned_to(user, bottom_level_2)
            end
          end
        end

        context "and that middle-level record is removed" do
          before do
            middle_level_2.destroy
          end

          context "each bottom level record" do
            it "inherits only the top-level role" do
              role1.should be_assigned_to(user, bottom_level_1)
              role2.should_not be_assigned_to(user, bottom_level_1)
              role1.should be_assigned_to(user, bottom_level_2)
              role2.should_not be_assigned_to(user, bottom_level_2)
            end
          end
        end
      end
    end
  end

  describe "indirect cycle" do
    let_constant(:record_class) do
      new_class(:Record, ActiveRecord::Base) do
        include AccessControl::Securable

        has_and_belongs_to_many(
          :parent_records,
          class_name: "Record",
          join_table: :records_records,
          foreign_key: :to_id,
          association_foreign_key: :from_id
        )
        has_and_belongs_to_many(
          :child_records,
          class_name: "Record",
          join_table: :records_records,
          foreign_key: :from_id,
          association_foreign_key: :to_id
        )

        inherits_permissions_from :parent_records

        requires_no_permissions!
      end
    end

    let(:top) { record_class.create! }
    let(:intermediate_1) { record_class.create!(parent_records: [top]) }
    let(:intermediate_2) {
      record_class.create!(parent_records: [top, intermediate_1])
    }
    let(:bottom) {
      record_class.create!(parent_records: [intermediate_2])
    }

    before do
      top.parent_records << bottom
      AccessControl.refresh_parents_of(top)
    end

    context "when a role is given at the top level record" do
      before do
        role1.assign_to(user, top)
      end

      it "gets inherited in the whole graph" do
        role1.should be_assigned_to(user, top)
        role1.should be_assigned_to(user, intermediate_1)
        role1.should be_assigned_to(user, intermediate_2)
        role1.should be_assigned_to(user, bottom)
      end

      context "and another is given at the bottom record" do
        before do
          role2.assign_to(user, bottom)
        end

        it "gets inherited in the whole graph" do
          role2.should be_assigned_to(user, top)
          role2.should be_assigned_to(user, intermediate_1)
          role2.should be_assigned_to(user, intermediate_2)
          role2.should be_assigned_to(user, bottom)
        end
      end

      context "and the same role is given at the bottom record" do
        before do
          role1.assign_to(user, bottom)
        end

        context "and later the top level is unassigned" do
          before do
            role1.unassign_from(user, top)
          end

          it "gets inherited in the whole graph due to the cycle" do
            role1.should be_assigned_to(user, top)
            role1.should be_assigned_to(user, intermediate_1)
            role1.should be_assigned_to(user, intermediate_2)
            role1.should be_assigned_to(user, bottom)
          end
        end
      end
    end
  end
end
