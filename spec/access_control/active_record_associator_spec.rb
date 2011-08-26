require 'spec_helper'

module AccessControl
  describe ActiveRecordAssociator do

    # A Mix-in module for ActiveRecord models for including an association with
    # a model of AccessControl.

    let(:base) do
      Class.new do
        include ActiveSupport::Callbacks
        define_callbacks :after_create
        after_create :after_create_callback
        def create
          do_create
          # Borrowed from ActiveSupport docs, but I think that there's an error
          # there... The block returns true if it want to stop the chain.
          run_callbacks(:after_create) { |result, object| result == false }
        end
        def after_create_callback; end
        def do_create; end
        def id
          "model's id"
        end
        def self.name
          'Model'
        end
      end
    end

    let(:model) { Class.new(base) { include ActiveRecordAssociator } }

    describe "#associate_with_access_control" do

      it "makes a has_one association with a model of AccessControl" do
        model.should_receive(:has_one).with(
          :an_association_name,
          :as => :a_polymorphic_name,
          :class_name => "a class name",
          :dependent => :destroy
        )
        model.associate_with_access_control(:an_association_name,
                                            'a class name',
                                            :a_polymorphic_name)
      end

      describe "access control object management" do

        let(:instance) { model.new }
        let(:ac_class) { Class.new }

        before do
          ac_class.stub(:create!)
          Object.send(:const_set, 'ACClass', ac_class)
          model.stub(:has_one)
          model.associate_with_access_control(:ac_class,
                                              'ACClass',
                                              :ac_class_able)
        end

        after do
          Object.send(:remove_const, 'ACClass')
        end

        describe "when application instance is created" do

          it "creates an access control object" do
            ac_class.should_receive(:create!).with(:ac_class_able => instance)
            instance.create
          end

          it "does it after creating the object" do
            ac_class.stub(:create!) do |params|
              params[:ac_class_able].id
            end
            instance.should_receive(:do_create).ordered
            instance.should_receive(:id).ordered
            instance.create
          end

          it "skips the creation if a callback returns false" do
            # The callback chain is stopped, so a rollback is made, and no
            # principal is created because our callback is not called at all.
            instance.stub(:after_create_callback).and_return(false)
            ac_class.should_not_receive(:create!)
            instance.create
          end

        end

      end
    end
  end
end
