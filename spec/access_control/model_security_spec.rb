require 'spec_helper'
require 'access_control/model_security'
require 'access_control/association_security'

module AccessControl

  describe AccessControl do
    it "is in strict mode by default" do
      AccessControl.should be_model_security_strict
    end
  end

  describe ModelSecurity do

    let(:model_klass) do
      class Object::Record < ActiveRecord::Base
        include AccessControl::ModelSecurity
        set_table_name 'records'
        def self.name
          'Record'
        end
      end
      Object::Record
    end

    let(:manager) { SecurityManager.new }

    before do
      AccessControl.configure do |config|
        config.default_query_permissions = []
        config.default_view_permissions = []
        config.default_create_permissions = []
        config.default_update_permissions = []
        config.default_destroy_permissions = []
        config.default_roles_on_create = nil
      end
      AccessControl.stub(:security_manager => manager)
      AccessControl.stub(:model_security_strict? => false)
      Principal.create_anonymous_principal!
    end

    after do
      model_klass
      Object.send(:remove_const, 'Record')
    end

    describe ModelSecurity::ClassMethods do

      describe "protection of belongs_to associations" do

        it "restricts the querying of an association" do
          model_klass.class_eval do
            belongs_to :record
            restrict_association :record
          end
          model_klass.association_restricted?(:record).should be_true
        end

        it "restricts the querying of an association based on system-wide "\
           "configuration option" do
          AccessControl.configure do |config|
            config.restrict_belongs_to_association = true
          end
          model_klass.class_eval do
            belongs_to :record
          end
          model_klass.association_restricted?(:record).should be_true
        end

        it "allows querying if the system-wide config allows and nothing "\
           "is explicitly defined" do
          AccessControl.configure do |config|
            config.restrict_belongs_to_association = false
          end
          model_klass.class_eval do
            belongs_to :record
          end
          model_klass.association_restricted?(:record).should be_false
        end

        it "can override the config option to restrict queries" do
          AccessControl.configure do |config|
            config.restrict_belongs_to_association = false
          end
          model_klass.class_eval do
            belongs_to :record
            restrict_association :record
          end
          model_klass.association_restricted?(:record).should be_true
        end

        it "can override the config option to allow queries" do
          AccessControl.configure do |config|
            config.restrict_belongs_to_association = true
          end
          model_klass.class_eval do
            belongs_to :record
            unrestrict_association :record
          end
          model_klass.association_restricted?(:record).should be_false
        end

        it "can restrict all associations at once" do
          AccessControl.configure do |config|
            config.restrict_belongs_to_association = false
          end
          model_klass.class_eval do
            belongs_to :record
            belongs_to :another_record
            restrict_all_associations!
          end
          model_klass.association_restricted?(:record).should be_true
          model_klass.association_restricted?(:another_record).should be_true
        end

        it "can unrestrict all associations at once" do
          AccessControl.configure do |config|
            config.restrict_belongs_to_association = true
          end
          model_klass.class_eval do
            belongs_to :record
            belongs_to :another_record
            unrestrict_all_associations!
          end
          model_klass.association_restricted?(:record).should be_false
          model_klass.association_restricted?(:another_record).
            should be_false
        end

      end

    end

  end
end
