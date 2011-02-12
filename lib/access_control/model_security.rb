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
        @ac_permissions_for_methods ||= Hash.new{|h, k| h[k] = Set.new}
      end

      def parent_association association_name=nil
        if association_name
          @ac_parent_association = association_name
        end
        @ac_parent_association
      end

      def query_permissions= permissions
        permissions = [permissions] unless permissions.is_a?(Array)
        @query_permissions = permissions
      end

      def query_permissions
        if !@query_permissions
          permissions = AccessControl.config.default_query_permissions
          permissions = [permissions] unless permissions.is_a?(Array)
          return (permissions + additional_query_permissions).uniq
        end
        @query_permissions
      end

      def additional_query_permissions= permissions
        permissions = [permissions] unless permissions.is_a?(Array)
        @additional_query_permissions = permissions
      end

      def additional_query_permissions
        @additional_query_permissions ||= []
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

    VALID_FIND_OPTIONS.push(:permissions, :load_permissions).uniq!

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
      options[:permissions] ||= query_permissions
      if !options[:permissions].is_a?(Array)
        raise ArgumentError, ':permissions must be an array'
      end
      merge_permission_options(options)
      find_every_without_restriction(options)
    end

    alias_method_chain :find_every, :restriction

    def unrestricted_find(*args)
      options = args.extract_options!
      options[:permissions] = []
      args << options
      find(*args)
    end

    private

      def merge_permission_options(options)
        return unless restrict_queries?
        if options[:permissions].any?

          options[:include] = merge_includes(
            options[:include],
            includes_for_permissions(options)
          ) if options[:load_permissions]

          options[:conditions] = merge_conditions(
            options[:conditions],
            conditions_for_permissions(options)
          )

          if options[:joins]
            options[:joins] = merge_joins(
              options[:joins],
              joins_for_permissions(options)
            )
          else
            options[:joins] = joins_for_permissions(options)
          end

        end
      end

      def includes_for_permissions(options)
        {
          :ac_node => {
            :ancestors => {
              :principal_assignments => {
                :role => :security_policy_items
              }
            }
          }
        }
      end

      def joins_for_permissions(options)
        base_joins = base_permission_joins
        # We need the same number of inclusions of `security_policy_items` as
        # the number of permissions to query for.
        associations = options[:permissions].size.times do |i|
          base_joins << "
            INNER JOIN `ac_security_policy_items`
              `ac_security_policy_items_chk_#{i}`
              ON `ac_security_policy_items_chk_#{i}`.`role_id` = 
                 `ac_roles_chk`.`id`".strip.squeeze(' ')
        end
        base_joins.join(' ')
      end

      def base_permission_joins
        principal_ids = AccessControl.get_security_manager.principal_ids
        if principal_ids.size == 1
          p_condition = "= #{connection.quote(principal_ids.first)}"
        else
          ids = principal_ids.map{|i| connection.quote(i)}.join(',')
          p_condition = "IN (#{ids})"
        end
        [
          "INNER JOIN `ac_nodes` `ac_nodes_chk` "\
            "ON `ac_nodes_chk`.securable_id = `records`.id "\
            "AND `ac_nodes_chk`.securable_type = 'Record'",
          "INNER JOIN `ac_paths` `ac_paths_chk` "\
            "ON `ac_paths_chk`.descendant_id = `ac_nodes_chk`.id",
          "INNER JOIN `ac_nodes` `ancestors_ac_nodes_chk` "\
            "ON `ancestors_ac_nodes_chk`.id = `ac_paths_chk`.ancestor_id",
          "INNER JOIN `ac_assignments` `ac_assignments_chk`"\
            "ON ac_assignments_chk.node_id = ancestors_ac_nodes_chk.id "\
            "AND ac_assignments_chk.`principal_id` #{p_condition}",
          "INNER JOIN `ac_roles` `ac_roles_chk` "\
            "ON `ac_roles_chk`.id = `ac_assignments_chk`.role_id",
        ]
      end

      def conditions_for_permissions(options)
        # We need the same number of 'AND' conditions as the number of
        # permissions to query for.
        options[:permissions].size.times.inject([]) do |conditions, i|
          conditions << condition_for_permission(options, i)
        end.join(' AND ')
      end

      def condition_for_permission(options, index)
        alias_name = "ac_security_policy_items_chk_#{index}"
        permission = connection.quote(options[:permissions][index])
        "(`#{alias_name}`.`permission_name` = #{permission})"
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
