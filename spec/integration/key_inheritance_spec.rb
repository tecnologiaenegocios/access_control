require 'spec_helper'

describe "key-based inheritance" do
  include WithConstants

  let_constant(:record_class) do
    new_class(:Record, ActiveRecord::Base) do
      include AccessControl::Securable

      belongs_to :parent, :foreign_key => :record_id, :class_name => "Record"
      inherits_permissions_from_key :record_id, :class_name => "Record"

      requires_no_permissions!
    end
  end

  let_constant(:user_class) do
    new_class(:User, ActiveRecord::Base) do
      include AccessControl::ActiveRecordSubject
    end
  end

  let(:role)          { AccessControl::Role.store(:name => "Role") }
  let(:user)          { User.create! }
  let(:parent_record) { Record.create! }
  let(:child_record)  { Record.create!(:parent => parent_record) }

  it "propagates roles from parent records to child record" do
    child_record = Record.create!(:parent => parent_record)

    role.assign_to(user, parent_record)
    role.should be_assigned_to(user, child_record)
  end

  it "propagates roles from grandparent records" do
    grandchild_record = Record.create!(:parent => child_record)

    role.assign_to(user, parent_record)
    role.should be_assigned_to(user, grandchild_record)
  end

  it "propagates roles assigned before the child creation" do
    role.assign_to(user, parent_record)

    child_record = Record.create!(:parent => parent_record)
    role.should be_assigned_to(user, child_record)
  end

  it "propagates the 'unassignment' of roles" do
    role.assign_to(user, parent_record)

    role.unassign_from(user, parent_record)
    role.should_not be_assigned_to(user, child_record)
  end
end
