require 'spec_helper'
require 'access_control/active_record_securable'
require 'access_control/null_securable'

module AccessControl
  describe NullSecurable do
    let(:base)  { Class.new }
    let(:model) { Class.new(base) }

    before { model.class_eval { include NullSecurable } }

    [:show, :list, :create, :update, :destroy].each do |t|
      describe ".#{t}_requires" do
        it "does nothing" do
          model.public_send(:"#{t}_requires", 'args') { }
        end
      end

      describe ".add_#{t}_requirement" do
        it "does nothing" do
          model.public_send(:"add_#{t}_requirement", 'args') { }
        end
      end

      describe ".permissions_required_to_#{t}" do
        it "returns an empty set" do
          model.public_send(:"permissions_required_to_#{t}", 'args') { }.
            should == Set.new
        end
      end
    end

    describe ".define_unrestricted_method" do
      it "does nothing" do
        model.define_unrestricted_method('args') { }
      end
    end

    describe ".unrestrict_method" do
      it "does nothing" do
        model.unrestrict_method('args') { }
      end
    end

    describe ".protect" do
      it "does nothing" do
        model.protect('args') { }
      end
    end

    describe ".inherits_permissions_from" do
      it "does nothing" do
        model.inherits_permissions_from('args') { }
      end
    end

    describe ".inherits_permissions_from_association" do
      it "does nothing" do
        model.inherits_permissions_from_association('args') { }
      end
    end

    describe ".requires_no_permissions!" do
      it "does nothing" do
        model.requires_no_permissions!
      end
    end

    context "with active record models" do
      let(:base) { ActiveRecord::Base }
      it "includes NullRestriction" do
        model.should include(NullRestriction)
      end
      it "includes ActiveRecordSecurable" do
        model.should include(ActiveRecordSecurable)
      end
    end
  end
end
