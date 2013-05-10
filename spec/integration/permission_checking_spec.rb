require 'spec_helper'

describe "permission checking" do
  include WithConstants

  let_constant(:record_class) do
    new_class(:Record, ActiveRecord::Base) do
      include AccessControl::Securable
      show_requires    nil
      list_requires    nil
      create_requires  'create_permission'
      update_requires  'update_permission'
      destroy_requires 'destroy_permission'

      attr_accessor :parent_record

      inherits_permissions_from :parent_record
    end
  end

  let_constant(:other_record_class) do
    new_class(:STIRecord, ActiveRecord::Base) do
      include AccessControl::Securable
      show_requires    nil
      list_requires    nil
      create_requires  'create_other_permission'
      update_requires  'update_other_permission'
      destroy_requires 'destroy_other_permission'

      attr_accessor :parent_record

      inherits_permissions_from :parent_record
    end
  end

  let_constant(:user_class) do
    new_class(:User, ActiveRecord::Base) do
      include AccessControl::ActiveRecordSubject
    end
  end

  let(:user) { user_class.create!(:name => 'user') }
  let(:root) { record_class.create!(:name => 'root') }
  let(:role) { AccessControl::Role.store(:name => 'global') }

  before do
    AccessControl.manager.current_subjects = [user]
  end

  after do
    AccessControl.no_manager
    AccessControl.reset
  end

  Spec::Matchers.define(:return_true) do
    description { |callable| "return true" }
    failure_message_for_should do |callable|
      "expected #{callable} to return true"
    end
    failure_message_for_should_not do |callable|
      "expected #{callable} to return false"
    end
    match { |callable| !!callable.call }
  end

  Spec::Matchers.define(:return_false) do
    description { |callable| "return false" }
    failure_message_for_should do |callable|
      "expected #{callable} to return false"
    end
    failure_message_for_should_not do |callable|
      "expected #{callable} to return true"
    end
    match { |callable| !callable.call }
  end

  Spec::Matchers.define(:return_value) do |value|
    description { |callable| "return #{value}" }
    failure_message_for_should do |callable|
      "expected #{callable} to return #{value}"
    end
    failure_message_for_should_not do |callable|
      "expected #{callable} to not return #{value}"
    end
    match { |callable| callable.call == value }
  end

  Spec::Matchers.define(:leave) do |block|
    description { |callable| "leave an expected result" }
    match { |callable| callable.call; block.call }
  end

  context "on create" do
    let(:permission) { AccessControl.registry.store('create_permission') }
    let(:parent)     { root }

    subject do
      lambda { record_class.new(:parent_record => parent,
                                :name => 'record').save! }
    end

    before do
      role.add_permissions([permission])
    end

    context "when the user has permissions to create" do
      before { role.globally_assign_to(user) }
      it { should return_true }
    end

    context "when the user has no permission to create" do
      it { should raise_error(AccessControl::Unauthorized) }
    end

    context "when the user has permission only through the parent" do
      let(:parent) { record_class.new(:parent_record => root,
                                      :name => 'parent') }

      before do
        role.assign_to(user, root)

        record_class.class_eval do
          after_create :persist_parent
          def persist_parent
            if parent_record && parent_record.new_record?
              parent_record.save!
            end
          end
        end
      end

      it { should return_true }
    end

    context "using #save" do
      subject do
        lambda { record_class.new(:parent_record => parent,
                                  :name => 'record').save }
      end

      context "when the user has permissions to create" do
        before { role.globally_assign_to(user) }
        it { should return_true }

        context "when underlying implementation returns false" do
          before do
            record_class.class_eval do
              validate { |r| r.errors.add(:foo, :bar) if r.name == 'record' }
            end
          end
          it { should return_false }
        end
      end

      context "when the user has no permission to create" do
        it { should raise_error(AccessControl::Unauthorized) }

        context "when underlying implementation returns false" do
          before do
            record_class.class_eval do
              validate { |r| r.errors.add(:foo, :bar) if r.name == 'record' }
            end
          end
          it { should return_false }
        end
      end
    end

    context "using #create!" do
      subject do
        lambda { record_class.create!(:parent_record => parent,
                                      :name => 'record') }
      end

      context "when the user has permissions to create" do
        before { role.globally_assign_to(user) }
        it { should return_true }
      end

      context "when the user has no permission to create" do
        it { should raise_error(AccessControl::Unauthorized) }
      end

      context "when the user has permission only through the parent" do
        let(:parent) { record_class.new(:parent_record => root,
                                        :name => 'parent') }

        before do
          role.assign_to(user, root)

          record_class.class_eval do
            after_create :persist_parent
            def persist_parent
              if parent_record && parent_record.new_record?
                parent_record.save!
              end
            end
          end
        end

        it { should_not raise_error }
      end
    end

    context "when an update is triggered inside the same transaction" do
      before do
        record_class.class_eval do
          after_save :resave!
          def resave!
            unless @resaved
              # This update should not trigger permission checking.
              @resaved = true
              save!
            end
          end
        end
      end

      context "when the user has permissions to create" do
        before { role.globally_assign_to(user) }
        it { should_not raise_error }
      end

      context "when the user has no permission to create" do
        it { should raise_error(AccessControl::Unauthorized) }
      end

      context "when the user has permission only through the parent" do
        let(:parent) { record_class.new(:parent_record => root,
                                        :name => 'parent') }

        before do
          role.assign_to(user, root)

          record_class.class_eval do
            after_create :persist_parent
            def persist_parent
              if parent_record && parent_record.new_record?
                parent_record.save!
              end
            end
          end
        end

        it { should_not raise_error }
      end
    end
  end

  context "on update" do
    subject { lambda { record.name = 'updated'; record.save! } }

    let(:permission) { AccessControl.registry.store('update_permission') }
    let(:record) do
      AccessControl.manager.trust do
        record_class.create!(:parent_record => root, :name => 'record')
      end
    end

    before do
      role.add_permissions([permission])
    end

    context "when the user has permissions to update" do
      before { role.globally_assign_to(user) }
      it { should return_true }
      it { should leave(lambda { record.reload.name == 'updated' }) }
    end

    context "when the user has no permission to update" do
      it { should raise_error(AccessControl::Unauthorized) }
    end

    context "using #save" do
      subject { lambda { record.name = 'updated'; record.save } }

      context "when the user has permissions to update" do
        before { role.globally_assign_to(user) }
        it { should return_true }
        it { should leave(lambda { record.reload.name == 'updated' }) }

        context "when underlying implementation returns false" do
          before do
            record_class.class_eval do
              validate { |r| r.errors.add(:foo, :bar) if r.name == 'updated' }
            end
          end
          it { should return_false }
        end
      end

      context "when the user has no permission to update" do
        it { should raise_error(AccessControl::Unauthorized) }

        context "when underlying implementation returns false" do
          before do
            record_class.class_eval do
              validate { |r| r.errors.add(:foo, :bar) if r.name == 'updated' }
            end
          end
          it { should return_false }
        end
      end
    end

    context "on parent change with permission to update" do
      let(:parent) do
        AccessControl.manager.trust do
          record_class.create!(:name => 'parent', :parent_record => root)
        end
      end

      let(:create_permission)  { AccessControl.registry.store('create_permission') }
      let(:destroy_permission) { AccessControl.registry.store('destroy_permission') }

      subject do
        lambda do
          record.parent_record = parent
          record.save!
        end
      end

      before do
        role.assign_to(user, root)
      end

      context "with permission to create and destroy" do
        before do
          role.add_permissions([create_permission, destroy_permission])
        end

        it { should_not raise_error }
      end

      context "without permission to create" do
        before { role.add_permissions([destroy_permission]) }
        it { should raise_error(AccessControl::Unauthorized) }
      end

      context "without permission to destroy" do
        before { role.add_permissions([create_permission]) }
        it { should raise_error(AccessControl::Unauthorized) }
      end
    end

    context "when the user has permission only through parent" do
      let(:record) do
        AccessControl.manager.trust do
          record_class.create!(:name => 'record')
        end
      end

      let(:parent) do
        other_record_class.new(:parent_record => root, :name => 'parent')
      end

      subject do
        lambda do
          record.parent_record = parent
          record.save!
        end
      end

      before do
        role.assign_to(user, root)

        record_class.class_eval do
          after_save :persist_parent
          def persist_parent
            if parent_record && parent_record.new_record?
              parent_record.save!
            end
          end

          create_requires nil
        end
      end

      # The parent will be persisted even without permissions in its record.
      it { should_not raise_error }
    end

    context "using #update_attribute" do
      subject { lambda { record.update_attribute(:name, 'updated') } }

      context "when the user has permissions to update" do
        before { role.globally_assign_to(user) }
        it { should return_true }
        it { should leave(lambda { record.reload.name == 'updated' }) }

        context "when underlying implementation returns false" do
          before do
            record_class.class_eval do
              before_update { |r| false }
            end
          end
          it { should return_false }
        end
      end

      context "when the user has no permission to update" do
        it { should raise_error(AccessControl::Unauthorized) }

        context "when underlying implementation returns false" do
          before do
            record_class.class_eval do
              before_update { |r| false }
            end
          end
          it { should return_false }
        end
      end
    end

    context "using #update_attributes" do
      subject { lambda { record.update_attributes(:name => 'updated') } }

      context "when the user has permissions to update" do
        before { role.globally_assign_to(user) }
        it { should return_true }
        it { should leave(lambda { record.reload.name == 'updated' }) }

        context "when underlying implementation returns false" do
          before do
            record_class.class_eval do
              validate { |r| r.errors.add(:foo, :bar) if r.name == 'updated' }
            end
          end
          it { should return_false }
        end
      end

      context "when the user has no permission to update" do
        it { should raise_error(AccessControl::Unauthorized) }

        context "when underlying implementation returns false" do
          before do
            record_class.class_eval do
              validate { |r| r.errors.add(:foo, :bar) if r.name == 'updated' }
            end
          end
          it { should return_false }
        end
      end
    end

    context "using #update_attributes!" do
      subject { lambda { record.update_attributes!(:name => 'updated') } }

      context "when the user has permissions to update" do
        before { role.globally_assign_to(user) }
        it { should return_true }
        it { should leave(lambda { record.reload.name == 'updated' }) }
      end

      context "when the user has no permission to update" do
        it { should raise_error(AccessControl::Unauthorized) }
      end
    end
  end

  context "on destroy" do
    let(:permission) { AccessControl.registry.store('destroy_permission') }
    let(:record) do
      AccessControl.manager.trust do
        record_class.create!(:parent_record => root, :name => 'record')
      end
    end

    before do
      role.add_permissions([permission])
    end

    subject { lambda { record.destroy } }

    context "when the user has permission" do
      before { role.assign_to(user, root) }
      it { should return_value(record) }
    end

    context "when the user has no permission" do
      it { should raise_error(AccessControl::Unauthorized) }
    end
  end
end

describe "creation without permission definition with reloading" do
  include WithConstants

  let_constant(:user_class) do
    new_class(:User, ActiveRecord::Base) do
      include AccessControl::ActiveRecordSubject
    end
  end

  let_constant(:record_class) do
    new_class(:Record, ActiveRecord::Base) do
      include AccessControl::Securable

      show_requires 'some_permission'
      list_requires 'some_permission'
      create_requires  nil
      update_requires  nil
      destroy_requires nil

      belongs_to :record
      has_many :records

      inherits_permissions_from_association :record, :record_id,
                                            :class_name => 'Record'

      attr_accessor :stop_proliferation

      after_create :proliferate
      def proliferate
        unless stop_proliferation
          records.create!(
            :name => 'child',
            :stop_proliferation => true
          )
        else
          record.reload
        end
      end
    end
  end

  subject { lambda { record_class.create!(:name => 'parent') } }

  before do
    user = user_class.create!
    AccessControl.manager.current_subjects = [user]
  end

  after do
    AccessControl.no_manager
    AccessControl.reset
  end

  it { should_not raise_error }
end