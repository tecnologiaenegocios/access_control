require 'spec_helper'

module AccessControl
  describe ActiveRecordAssociator do

    # A Mix-in module for ActiveRecord models for including an association with
    # a model of AccessControl.

    let(:callbacks) do
      Module.new do
        def just_after_create(&block)
          just_after_create_callbacks << block
        end
        def just_after_destroy(&block)
          just_after_destroy_callbacks << block
        end
        def just_after_create_callbacks
          @just_after_create_callbacks ||= []
        end
        def just_after_destroy_callbacks
          @just_after_destroy_callbacks ||= []
        end
      end
    end

    let(:model) do
      cls = Class.new do
        def create
          self.class.just_after_create_callbacks.each do |block|
            instance_eval(&block)
          end
        end

        def destroy
          self.class.just_after_destroy_callbacks.each do |block|
            instance_eval(&block)
          end
        end
      end
      cls
    end

    let(:instance)      { model.new }
    let(:ac_associated) { stub('object from access control') }

    describe ".setup_association" do
      before do
        model.extend(callbacks)
        instance.stub(:access_control_object => ac_associated)
        ActiveRecordAssociator.setup_association(:association, model) do
          access_control_object
        end
      end

      it "defines a method which returns the access control object" do
        instance.association.should be ac_associated
      end

      context "when a record is created" do
        it "persists the associated access control object" do
          ac_associated.should_receive(:persist)
          instance.create
        end
      end

      context "when a record is destroyed" do
        it "destroys the associated access control object" do
          ac_associated.should_receive(:destroy)
          instance.destroy
        end
      end
    end
  end
end
