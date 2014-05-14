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

          it "inherits all" do
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

            it "inherits all" do
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
end
