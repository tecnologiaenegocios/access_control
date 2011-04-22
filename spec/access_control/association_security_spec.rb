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

      let(:principal) { Principal.create!(:subject_type => 'User',
                                          :subject_id => 1) }
      let(:user) { stub('user', :principal => principal) }
      let(:controller) { stub('controller',
                              :current_user => user,
                              :current_groups => []) }
      let(:manager) { SecurityManager.new(controller) }

      before do
        Node.create_global_node!
        AccessControl.stub!(:security_manager).and_return(manager)
        model_klass.query_requires 'query'
        model_klass.view_requires 'view'
        model_klass.create_requires :none
      end

      describe "#find_target" do

        describe AssociationSecurity::BelongsTo do
          it "returns records without restriction" do
            model_klass.class_eval do
              belongs_to :record
            end
            first_record = model_klass.create!
            second_record = model_klass.create!(:record_id => first_record.id)
            lambda {
              second_record.record.should == first_record
            }.should_not raise_exception
          end
        end

        describe AssociationSecurity::BelongsToPolymorphic do
          it "returns records without restriction" do
            model_klass.class_eval do
              belongs_to :recordable, :polymorphic => true
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

          it "returns nil if there's type column is empty" do
            model_klass.class_eval do
              belongs_to :recordable, :polymorphic => true
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
