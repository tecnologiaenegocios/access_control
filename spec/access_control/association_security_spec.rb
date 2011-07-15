require 'spec_helper'
require 'access_control/association_security'
require 'access_control/model_security'

module AccessControl
  describe AssociationSecurity do

    let(:model_klass) do
      class Object::Record < ActiveRecord::Base
        set_table_name 'records'
        def self.name
          'Record'
        end
      end
      Object::Record
    end

    after do
      model_klass
      Object.send(:remove_const, 'Record')
    end

    describe "unrestricted query" do

      let(:manager) { SecurityManager.new }

      before do
        AccessControl.stub(:security_manager).and_return(manager)
        Node.create_global_node!
        Principal.create_anonymous_principal!
        model_klass.query_requires 'query'
        model_klass.view_requires 'view'
        model_klass.create_requires :none
      end

      describe "#find_target" do

        describe AssociationSecurity::BelongsTo do

          before do
            model_klass.class_eval do
              belongs_to :record
            end
          end

          describe "when the class doesn't restrict for this association" do

            before do
              model_klass.stub(:association_restricted?).and_return(false)
            end

            it "returns records without restriction" do
              first_record = model_klass.create!
              second_record = model_klass.create!(:record_id => first_record.id)
              lambda {
                second_record.record.should == first_record
              }.should_not raise_exception
            end

          end

          describe "when the class enforces restriction" do

            before do
              model_klass.stub(:association_restricted?).and_return(true)
            end

            it "verifies the required permissions" do
              first_record = model_klass.create!
              second_record = model_klass.create!(:record_id => first_record.id)
              lambda {
                second_record.record
              }.should raise_exception(AccessControl::Unauthorized)
            end

          end
        end

        describe AssociationSecurity::BelongsToPolymorphic do

          before do
            model_klass.class_eval do
              belongs_to :recordable, :polymorphic => true
            end
          end

          describe "when the class doesn't restrict for this association" do

            before do
              model_klass.stub(:association_restricted?).and_return(false)
            end

            it "returns records without restriction" do
              model_klass.class_eval do
                def [] attr
                  case attr.to_s
                  when 'recordable_type' then 'Record'
                  when 'recordable_id' then record_id
                  else
                    super
                  end
                end
              end
              first_record = model_klass.create!
              second_record = model_klass.create!(:record_id => first_record.id)
              lambda {
                second_record.recordable.should == first_record
              }.should_not raise_exception
            end

            it "doesn't break if the type can't be determined" do
              model_klass.class_eval do
                def [] attr
                  case attr.to_s
                  when 'recordable_type' then nil
                  when 'recordable_id' then nil
                  else
                    super
                  end
                end
              end
              lambda {
                model_klass.create!.recordable.should be_nil
              }.should_not raise_exception
            end

          end

          describe "when the class enforces restriction" do

            before do
              model_klass.stub(:association_restricted?).and_return(true)
            end

            it "verifies the required permissions" do
              model_klass.class_eval do
                def [] attr
                  case attr.to_s
                  when 'recordable_type' then 'Record'
                  when 'recordable_id' then record_id
                  else
                    super
                  end
                end
              end
              first_record = model_klass.create!
              second_record = model_klass.create!(:record_id => first_record.id)
              lambda {
                second_record.recordable.should == first_record
              }.should raise_exception(AccessControl::Unauthorized)
            end

            it "still doesn't break if the type can't be determined" do
              model_klass.class_eval do
                def [] attr
                  case attr.to_s
                  when 'recordable_type' then nil
                  when 'recordable_id' then nil
                  else
                    super
                  end
                end
              end
              lambda {
                model_klass.create!.recordable.should be_nil
              }.should_not raise_exception
            end

          end
        end

      end

    end
  end
end
