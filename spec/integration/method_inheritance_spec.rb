require 'spec_helper'

describe "method-based inheritance" do
  include WithConstants

  let_active_record(:Record) do
    include AccessControl::Securable

    has_and_belongs_to_many(
      :parent_records,
      :class_name              => 'Record',
      :foreign_key             => :from_id,
      :association_foreign_key => :to_id
    )

    inherits_permissions_from :parent_records_method

    def parent_records_method
      parent_records
    end

    requires_no_permissions!
  end

  let_active_record(:User) do
    include AccessControl::ActiveRecordSubject
  end

  let(:parent_record) { Record.create! }
  let(:child_record)  { Record.create!(:parent_records => [parent_record]) }
  let(:user)          { User.create! }
  let(:role)          { AccessControl::Role.store(:name => "Role") }

  it "propagates roles from parent records to child records" do
    child_record = Record.create!(:parent_records => [parent_record])

    role.assign_to(user, parent_record)
    role.should be_assigned_to(user, child_record)
  end

  it "propagates roles from grandparent records" do
    grandchild_record = Record.create!(:parent_records => [parent_record])

    role.assign_to(user, parent_record)
    role.should be_assigned_to(user, grandchild_record)
  end

  it "propagates roles assigned before the child creation" do
    role.assign_to(user, parent_record)

    child_record = Record.create!(:parent_records => [parent_record])
    role.should be_assigned_to(user, child_record)
  end

  it "propagates the 'unassignment' of roles" do
    role.assign_to(user, parent_record)

    role.unassign_from(user, parent_record)
    role.should_not be_assigned_to(user, child_record)
  end

  it "works just fine with repetitions" do
    child_record = Record.create!(:parent_records => [parent_record,
                                                      parent_record])

    role.assign_to(user, parent_record)
    role.should be_assigned_to(user, child_record)
  end
end
