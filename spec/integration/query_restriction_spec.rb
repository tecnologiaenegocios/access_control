require 'spec_helper'

describe "query restriction" do
  include WithConstants

  let_constant(:parent_class) do
    new_class(:Record, ActiveRecord::Base) do
      include AccessControl::Securable
      requires_no_permissions!
    end
  end

  let_constant(:record_class) do
    new_class(:STIRecord, ActiveRecord::Base) do
      include AccessControl::Securable
      requires_no_permissions!
      attr_accessor :parent
      inherits_permissions_from :parent
    end
  end

  let_constant(:specialized_record_class) do
    new_class(:SpecializedSTIRecord, record_class)
  end

  let_constant(:super_specialized_record_class) do
    new_class(:SuperSpecializedSTIRecord, specialized_record_class)
  end

  let_constant(:user_class) do
    new_class(:User, ActiveRecord::Base) do
      include AccessControl::ActiveRecordSubject
    end
  end

  let(:user) { user_class.create!(name: 'user') }
  let(:role) { AccessControl::Role.store(name: 'global') }
  let(:parent) { parent_class.create! }

  let!(:record) do
    record_class.create!(name: 'record', parent: parent)
  end

  let!(:specialized_record) do
    specialized_record_class
      .create!(name: 'specialized record', parent: parent)
  end

  let!(:super_specialized_record) do
    super_specialized_record_class
      .create!(name: 'super specialized record', parent: parent)
  end

  after do
    AccessControl.no_manager
    AccessControl.reset
    AccessControl::PermissionInspector.clear_role_cache
  end

  describe "with globally-assigned role" do
    before do
      role.globally_assign_to(user)
      AccessControl.manager.current_subjects = [user]
    end

    it_should_behave_like 'query restriction'
  end

  describe "with role assigned in a common parent record" do
    before do
      role.assign_to(user, parent)
      AccessControl.manager.current_subjects = [user]
    end

    it_should_behave_like 'query restriction'
  end
end
