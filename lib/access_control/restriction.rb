require 'access_control/exceptions'
require 'access_control/util'

module AccessControl

  module Restriction

    def self.included(base)
      base.extend(ClassMethods)
      base.class_eval do
        named_scope :with_permissions, WithPermissionScope.options(base)
        named_scope :with_unblocked_nodes, WithUnblockedNodesScope.options
        named_scope :granted, GrantedScope.options(base)
        class << self
          alias_method_chain :find, :permissions
        end
      end
    end

    module WithPermissionScope

      def self.options(base)
        lambda do
          {:joins => joins(base), :conditions => conditions}
        end
      end

      def self.joins(base)
        Util.prettify_sql(<<-SQL)
          LEFT JOIN `ac_nodes` ON \n\
            `ac_nodes`.securable_id = #{base.quoted_table_name}.id AND \n\
            `ac_nodes`.securable_type = '#{base.name}' \n\
          LEFT JOIN `ac_assignments` ON \n\
            `ac_assignments`.node_id = `ac_nodes`.id \n\
          LEFT JOIN `ac_roles` ON \n\
            `ac_roles`.id = `ac_assignments`.role_id \n\
          LEFT JOIN `ac_security_policy_items` ON \n\
            `ac_security_policy_items`.role_id = `ac_roles`.id
        SQL
      end

      def self.conditions
        principal_ids = AccessControl.security_manager.principal_ids
        if principal_ids.size == 1
          return {:'ac_security_policy_items.principal_id' => principal_ids.first}
        end
        {:'ac_security_policy_items.principal_id' => principal_ids}
      end

    end

    module WithUnblockedNodesScope
      def self.options
        { :conditions => { :'ac_nodes.block' => 0 } }
      end
    end

    module GrantedScope
      def self.options(base)
        lambda do |permissions|
          Restricter.new(base).options(permissions)
        end
      end
    end

    module ClassMethods
      def find_with_permissions(*args)
        with_permissions.find_without_permissions(*args)
      end
    end

  end

  class Restricter

    def initialize(model)
      raise CannotRestrict unless model.is_a?(Restriction)
      @model = model
    end

  end

end
