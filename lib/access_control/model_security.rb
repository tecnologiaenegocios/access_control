require 'access_control/configuration'
require 'access_control/security_manager'
require 'access_control/security_proxy'

module AccessControl
  module ModelSecurity

    module ClassMethods

      def protect method_name, options
        permissions = options[:with]
        permissions_for_methods[method_name.to_s].merge(permissions)
      end

      def permissions_for method_name
        permissions_for_methods[method_name.to_s]
      end

      def permissions_for_methods
        @_permissions_for_methods ||= Hash.new{|h, k| h[k] = Set.new}
      end

      def parent_association association_name=nil
        if association_name
          @_parent_association = association_name
        end
        @_parent_association
      end

      def access_permission permission=nil
        if permission
          @_access_permission = permission
        end
        @_access_permission || AccessControl.config.default_access_permission
      end

    end

    module InstanceMethods

      def self.included base
        base.extend(ClassMethods)
        base.has_one :ac_node,
                     :as => :securable,
                     :class_name => ::AccessControl::Model::Node.name,
                     :dependent => :destroy
        base.class_eval do
          def ac_node_with_automatic_creation
            return if new_record?
            current_node = ac_node_without_automatic_creation
            return current_node if current_node
            create_nodes
          end
          alias_method_chain :ac_node, :automatic_creation
        end
      end

      def parents
        return [] unless self.class.parent_association
        Set.new.merge(send(self.class.parent_association)).to_a
      end

    end

  end
end

class ActiveRecord::Base

  include AccessControl::ModelSecurity::InstanceMethods

  class << self

    def securable?
      true
    end

    def allocate_with_security *args
      object = allocate_without_security *args
      return object unless manager = AccessControl.get_security_manager
      return object unless object.class.securable?
      AccessControl::SecurityProxy.new(object)
    end
    alias_method_chain :allocate, :security

    def find_every_with_restriction(options)
      include_permission_associations_and_conditions(options)
      find_every_without_restriction(options)
    end

    alias_method_chain :find_every, :restriction

    def unrestricted_find(*args)
      disable_query_restriction
      find(*args)
    ensure
      re_enable_query_restriction
    end

    private

      def include_permission_associations_and_conditions(options)
        return unless restrict_queries?
        options[:include] = merge_includes(
          options[:include],
          {
            :ac_node => {
              :ancestors => {
                :principal_assignments => {
                  :role => :security_policy_items
                }
              }
            }
          }
        )
        permission = self.connection.quote(access_permission)
        options[:conditions] = merge_conditions(
          options[:conditions],
          "`ac_security_policy_items`.`permission_name` = #{permission}"
        )
      end

      def restrict_queries?
        return false unless securable?
        return false unless manager = AccessControl.get_security_manager
        manager.restrict_queries?
      end

      def disable_query_restriction
        manager = AccessControl.get_security_manager
        return unless manager
        manager.restrict_queries = false
      end

      def re_enable_query_restriction
        manager = AccessControl.get_security_manager
        return unless manager
        manager.restrict_queries = true
      end

  end

  after_create :create_nodes
  after_update :update_parent_nodes
  before_validation :disable_query_restriction
  after_validation :re_enable_query_restriction

  private

    def create_nodes
      AccessControl::Model::Node.create!(
        :securable => self, :parents => parents.map(&:ac_node)
      ) if self.class.securable?
    end

    def update_parent_nodes
      ac_node.parents = parents.map(&:ac_node) if ac_node
    end

    def disable_query_restriction
      self.class.send(:disable_query_restriction)
      # This must return true or else validation stop and the record is
      # considered invalid.
      true
    end

    def re_enable_query_restriction
      self.class.send(:re_enable_query_restriction)
    end

end
