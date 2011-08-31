require 'spec_helper'

module AccessControl
  describe ActiveRecordAssociator do

    # A Mix-in module for ActiveRecord models for including an association with
    # a model of AccessControl.

    let(:base) do
      Class.new do
        def pk
          1000
        end
        def self.primary_key
          'pk'
        end
        def self.name
          'Model'
        end
      private
        def create
          create_without_callbacks
          run_after_create_callbacks
        end
        def create_without_callbacks; do_create; end
        def run_after_create_callbacks; end
        def do_create; end
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
          model.associate_with_access_control(:ac_class, 'ACClass',
                                              :ac_class_able)
        end

        after do
          Object.send(:remove_const, 'ACClass')
        end

        describe "when application instance is created" do

          it "creates an access control object" do
            ac_class.should_receive(:create!).
              with(:ac_class_able_id => instance.pk,
                   :ac_class_able_type => instance.class.name)
            instance.send(:create)
          end

          it "does it right after creating the object" do
            ac_class.stub(:create!) do |params|
              instance.created
            end
            instance.should_receive(:do_create).ordered
            instance.should_receive(:created).ordered
            instance.send(:create)
          end

          it "does it right before any after callback is called" do
            ac_class.stub(:create!) do |params|
              instance.created
            end
            instance.should_receive(:created).ordered
            instance.should_receive(:run_after_create_callbacks).ordered
            instance.send(:create)
          end

        end

      end
    end
  end
end
