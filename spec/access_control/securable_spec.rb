require 'spec_helper'
require 'access_control/securable'

module AccessControl
  describe Securable do
    let(:model) { Class.new }

    context "when access control is not disabled" do
      before do
        AccessControl.stub(:disabled?).and_return(false)
        model.send(:include, Securable)
      end

      it "doesn't include NullSecurable" do
        model.should_not include NullSecurable
      end

      it "includes Macros" do
        model.singleton_class.should include(Macros)
      end

      it "includes MethodProtection" do
        model.should include(MethodProtection)
      end

      describe "with active record models" do
        let(:model) { Class.new(ActiveRecord::Base) }

        it "includes ActiveRecordSecurable" do
          model.should include(ActiveRecordSecurable)
        end

        it "includes Inheritance" do
          model.should include(Inheritance)
        end

        it "includes Restriction" do
          model.should include(Restriction)
        end
      end
    end

    context "when access control is disabled" do
      before do
        AccessControl.stub(:disabled?).and_return(true)
        model.send(:include, Securable)
      end

      it "includes NullSecurable" do
        model.should include NullSecurable
      end

      it "doesn't include Macros" do
        model.singleton_class.should_not include(Macros)
      end

      it "doesn't include MethodProtection" do
        model.should_not include MethodProtection
      end

      context "with active record models" do
        let(:model) { Class.new(ActiveRecord::Base) }

        # ActiveRecordSecurable is included by NullSecurable

        it "doesn't include Inheritance" do
          model.should_not include Inheritance
        end

        it "doesn't include Restriction" do
          model.should_not include Restriction
        end
      end
    end
  end
end
