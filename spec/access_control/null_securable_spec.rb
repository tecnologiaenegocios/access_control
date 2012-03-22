require 'spec_helper'
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

    describe ".inherits_permissions_from_key" do
      it "does nothing" do
        model.inherits_permissions_from_key('args') { }
      end
    end

    context "with active record models" do
      let(:base) { ActiveRecord::Base }

      it "includes ActiveRecordSecurable" do
        # This module adds support for nodes in ActiveRecord instances, and
        # even with NullSecurable we still need them.
        # TODO What about NullNodes?
        model.should include(ActiveRecordSecurable)
      end

      it "includes NullRestriction" do
        model.should include(NullRestriction)
      end
    end
  end
end
