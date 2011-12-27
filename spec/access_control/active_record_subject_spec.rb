require 'spec_helper'
require 'access_control/active_record_subject'

module AccessControl
  describe ActiveRecordSubject do
    # A Mix-in module for User-like ActiveRecord models.

    let(:base) do
      Class.new do
        def create
          self.class.just_after_callback_chains.execute(self, :create)
        end
        def update
          self.class.just_after_callback_chains.execute(self, :update)
        end
        def destroy
          self.class.just_after_callback_chains.execute(self, :destroy)
        end
      end
    end

    let(:model) { Class.new(base) }

    it "includes just after callbacks" do
      model.send(:include, ActiveRecordSubject)
      model.should include(ActiveRecordJustAfterCallback)
    end

    describe "association to Principal" do
      let(:principal) { stub('principal') }
      let(:instance)  { model.new }

      before do
        Principal.stub(:for_subject).with(instance).and_return(principal)
        model.send(:include, ActiveRecordSubject)
      end

      it "returns a principal for the instance" do
        instance.ac_principal.should be principal
      end

      specify "once the principal is computed, the principal is cached" do
        old_result = instance.ac_principal # should cache
        Principal.should_not_receive(:for_subject)
        instance.ac_principal.should be old_result
      end

      it "persists the principal when the record is saved" do
        principal.should_receive(:persist!)
        instance.create
      end

      it "destroys the principal when the record is destroyed" do
        principal.should_receive(:destroy)
        instance.destroy
      end
    end
  end
end
