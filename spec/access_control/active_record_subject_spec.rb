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
        def self.primary_key
          'pk'
        end
        def pk
          123
        end
      end
    end

    let(:model) { Class.new(base) }

    it "includes just after callbacks" do
      model.send(:include, ActiveRecordSubject)
      model.should include(ActiveRecordJustAfterCallback)
    end

    context "in a model with ActiveRecordSubject" do
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

      it "persists the principal when the record is created" do
        principal.should_receive(:subject_id=).with(instance.pk).ordered
        principal.should_receive(:persist!).ordered
        instance.create
      end

      it "persists the principal when the record is updated and a principal "\
         "wasn't created yet" do
        instance.stub(:ac_principal => principal)
        principal.stub(:persisted?).and_return(false)
        principal.should_receive(:persist!)
        instance.update
      end

      it "does nothing when the record is updated and a principal was already "\
         "created" do
        instance.stub(:ac_principal => principal)
        principal.stub(:persisted?).and_return(true)
        principal.should_not_receive(:persist!)
        instance.update
      end

      it "destroys the principal when the record is destroyed" do
        principal.should_receive(:destroy)
        instance.destroy
      end
    end
  end
end
