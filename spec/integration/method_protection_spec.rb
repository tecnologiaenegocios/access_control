require 'spec_helper'

shared_examples_for "method protection" do
  include WithConstants

  let_constant(:user_class) do
    new_class(:User, ActiveRecord::Base) do
      include AccessControl::ActiveRecordSubject
    end
  end
  let(:user) { User.create! }
  let(:role) { AccessControl::Role.store(:name => 'role') }

  before do
    role.assign_to(user, record)
    AccessControl.manager.current_subjects = [user]
  end

  after do
    AccessControl.no_manager
    AccessControl.reset
    AccessControl::PermissionInspector.clear_role_cache
  end

  Spec::Matchers.define(:be_unauthorized) do
    description { |callable| "be unauthorized" }
    failure_message_for_should do |callable|
      "expected #{callable} to raise AccessControl::Unauthorized"
    end
    failure_message_for_should_not do |callable|
      "expected #{callable} to not raise AccessControl::Unauthorized"
    end
    match do |callable|
      begin
        callable.call
      rescue AccessControl::Unauthorized
        true
      else
        false
      end
    end
  end

  Spec::Matchers.define(:return_the_original_result) do
    description { |callable| "return the original result" }
    match { |callable| callable.call == 'result' }
  end

  def add_permissions(*names)
    permissions = names.map { |name| AccessControl.registry.fetch(name) }
    role.add_permissions(permissions)
  end

  context "when the user has no permissions" do
    it { should be_unauthorized }
  end

  if protection_redefined_in_subclass?
    context "when the user has only permission required in superclass" do
      before { add_permissions('super') }
      it { should be_unauthorized }
    end

    context "when the user has only permission required in subclass" do
      before { add_permissions('sub') }
      it { should_not be_unauthorized }
      it { should return_the_original_result }
    end

    context "when the user has both permissions" do
      before { add_permissions('super', 'sub') }
      it { should_not be_unauthorized }
      it { should return_the_original_result }
    end
  else
    context "when the user has the permission required" do
      before { add_permissions('super') }
      it { should_not be_unauthorized }
      it { should return_the_original_result }
    end
  end
end

describe AccessControl::MethodProtection do
  include WithConstants

  let_constant(:superclas) do
    new_class(:STIRecord, ActiveRecord::Base) do
      include AccessControl::Securable
      requires_no_permissions!
      protect :name, :with => 'super'
      protect :foo,  :with => 'super'
      def foo; 'result'; end
    end
  end

  let(:record) { STISubRecord.create!(:name => 'result') }

  describe "subclass without redefinition of protection" do
    let_constant(:subclass) do
      new_class(:STISubRecord, superclas) do
        requires_no_permissions!
      end
    end

    def self.protection_redefined_in_subclass?; false; end

    before { AccessControl::Registry.store('sub') }

    describe "for column" do
      subject { lambda { record.name } }

      describe "without column method redefinition" do
        it_should_behave_like "method protection"
      end

      describe "with column method redefinition, calling super" do
        before { subclass.class_eval { def name; super; end } }
        it_should_behave_like "method protection"
      end
    end

    describe "for method" do
      subject { lambda { record.foo } }

      describe "without method redefinition" do
        it_should_behave_like "method protection"
      end

      describe "with method redefinition, calling super" do
        before { subclass.class_eval { def foo; super; end } }
        it_should_behave_like "method protection"
      end
    end
  end

  describe "redefinition of protection in subclass" do
    let_constant(:subclass) do
      new_class(:STISubRecord, superclas) do
        requires_no_permissions!
        protect :name, :with => 'sub'
        protect :foo,  :with => 'sub'
      end
    end

    def self.protection_redefined_in_subclass?; true; end

    describe "for column" do
      subject { lambda { record.name } }

      describe "without column method redefinition" do
        it_should_behave_like "method protection"
      end

      describe "with column method redefinition, without calling super" do
        before { subclass.class_eval { def name; self[:name]; end } }
        it_should_behave_like "method protection"
      end

      describe "with column method redefinition, calling super" do
        before { subclass.class_eval { def name; super end } }
        it_should_behave_like "method protection"
      end
    end

    describe "for method" do
      subject { lambda { record.foo } }

      describe "without method redefinition" do
        it_should_behave_like "method protection"
      end

      describe "with method redefinition, without calling super" do
        before { subclass.class_eval { def foo; 'result'; end } }
        it_should_behave_like "method protection"
      end

      describe "with method redefinition, calling super" do
        before { subclass.class_eval { def foo; super; end } }
        it_should_behave_like "method protection"
      end
    end
  end
end
