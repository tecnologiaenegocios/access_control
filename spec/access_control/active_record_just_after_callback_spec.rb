require 'spec_helper'

module AccessControl
  describe ActiveRecordJustAfterCallback do

    # In Rails 2.x it is not possible to prepend callbacks as it is possible to
    # do with controller filters (at least we could not found a way to do that
    # cleanly).
    #
    # This let us with the need to obtrusively patch +_without_callback+
    # methods, which by the way we couldn't do without reading the ActiveRecord
    # source.  This breaks in Rails 3.x, but it's ActiveSupport has a way to
    # prepend callbacks which is not obtrusive.
    let(:base) do
      Class.new do
        def create_without_callbacks;  do_action(:create); end
        def update_without_callbacks;  do_action(:update); end
        def destroy_without_callbacks; do_action(:destroy); end
        def do_action(type); end
        def do_after_action(type); end
        def do_other_after_action(type); end
      end
    end

    let(:model) { Class.new(base) }

    let(:instance) { model.new }

    before do
      model.class_eval do
        include ActiveRecordJustAfterCallback

        just_after_create  { do_after_action(:create) }
        just_after_update  { do_after_action(:update) }
        just_after_destroy { do_after_action(:destroy) }
      end
    end

    [:create, :update, :destroy].each do |meth|
      it "executes blocks after #{meth}_without_callback method in superclass" do
        instance.should_receive(:do_action).with(meth).ordered
        instance.should_receive(:do_after_action).with(meth).ordered
        instance.send(:"#{meth}_without_callbacks")
      end
    end

    describe "with more than one declaration for each type" do
      before do
        model.class_eval do
          just_after_create  { do_other_after_action(:create) }
          just_after_update  { do_other_after_action(:update) }
          just_after_destroy { do_other_after_action(:destroy) }
        end
      end

      [:create, :update, :destroy].each do |meth|
        it "executes blocks in order" do
          instance.should_receive(:do_after_action).with(meth).ordered
          instance.should_receive(:do_other_after_action).with(meth).ordered
          instance.send(:"#{meth}_without_callbacks")
        end
      end
    end
  end
end
