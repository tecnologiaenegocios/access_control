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

      [:query, :view].each do |name|
        define_method(:"#{name}_permissions=") do |permissions|
          permissions = [permissions] unless permissions.is_a?(Array)
          instance_variable_set("@#{name}_permissions", permissions)
        end

        define_method(:"#{name}_permissions") do
          if !instance_variable_get("@#{name}_permissions")
            permissions = AccessControl.config.send(
              "default_#{name}_permissions"
            )
            permissions = [permissions] unless permissions.is_a?(Array)
            return (permissions +
                    send("additional_#{name}_permissions")).uniq
          end
          instance_variable_get("@#{name}_permissions")
        end

        define_method(:"additional_#{name}_permissions=") do |permissions|
          permissions = [permissions] unless permissions.is_a?(Array)
          instance_variable_set("@additional_#{name}_permissions", permissions)
        end

        define_method(:"additional_#{name}_permissions") do
          unless v = instance_variable_get("@additional_#{name}_permissions")
            v = instance_variable_set("@additional_#{name}_permissions", [])
          end
          v
        end
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

    def find_one_with_unauthorized(id, options)
      old_joins = options[:old_joins]
      old_joins = old_joins.dup if old_joins
      options[:permissions] ||= (view_permissions | query_permissions)
      begin
        return find_one_without_unauthorized(id, options)
      rescue ActiveRecord::RecordNotFound => e
        disable_query_restriction
        options[:joins] = old_joins
        result = find_one_without_unauthorized(id, options) rescue nil
        re_enable_query_restriction
        raise e if !result
        raise AccessControl::Unauthorized
      end
    end

    alias_method_chain :find_one, :unauthorized

    def unrestricted_find(*args)
      disable_query_restriction
      result = find(*args)
      re_enable_query_restriction
      result
    end

    private

      def merge_permission_options(options)
        merge_permission_includes(options)
        return unless restrict_queries?
        if options[:permissions].any?
          merge_permission_joins(options)
        end
      end

      def merge_permission_includes(options)
        options[:include] = merge_includes(
          options[:include],
          includes_for_permissions(options)
        ) if options[:load_permissions]
      end

      def merge_permission_joins(options)
        if options[:joins]
          options[:joins] = merge_joins(
            options[:joins],
            joins_for_permissions(options)
          )
        else
          options[:joins] = joins_for_permissions(options)
        end
        fix_select_clause_for_permission_joins(options)
      end

      def fix_select_clause_for_permission_joins(options)
        options[:select] ||= '*'
        options[:select] = prefix_with_table_name(options[:select])
      end

      def prefix_with_table_name(select_clause)
        'DISTINCT ' + select_clause.split(',').inject([]) do |s, token|
          t = token.strip.gsub('`', '')
          next s << "#{quoted_table_name}.*" if t == '*'
          if columns_hash.keys.include?(t)
            next s << "#{quoted_table_name}.`#{t}`"
          end
          # Functions or other references are not prefixed.
          s << token
        end.join(', ')
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

        c = connection
        t = table_name
        pk = primary_key
        principal_ids = AccessControl.get_security_manager.principal_ids

        if principal_ids.size == 1
          p_condition = "= #{c.quote(principal_ids.first)}"
        else
          ids = principal_ids.map{|i| c.quote(i)}.join(',')
          p_condition = "IN (#{ids})"
        end

        # We need the same number of inclusions of the whole associations
        # towards `ac_security_policy_items` as the number of permissions to
        # query for.

        options[:permissions].each_with_index.inject("") do |j, (p, i)|
          j << "

            INNER JOIN `ac_nodes` `nodes_chk_#{i}`
            ON `nodes_chk_#{i}`.`securable_id` = `#{t}`.`#{pk}`
            AND `nodes_chk_#{i}`.`securable_type` = #{c.quote(name)}

            INNER JOIN `ac_paths` `paths_chk_#{i}`
            ON `paths_chk_#{i}`.`descendant_id` = `nodes_chk_#{i}`.`id`

            INNER JOIN `ac_nodes` `anc_nodes_chk_#{i}`
            ON `anc_nodes_chk_#{i}`.`id` = `paths_chk_#{i}`.`ancestor_id`

            INNER JOIN `ac_assignments` `assignments_chk_#{i}`
            ON `assignments_chk_#{i}`.`node_id` = `anc_nodes_chk_#{i}`.`id`
            AND `assignments_chk_#{i}`.`principal_id` #{p_condition}

            INNER JOIN `ac_roles` `roles_chk_#{i}`
              ON `roles_chk_#{i}`.`id` = `assignments_chk_#{i}`.`role_id`

            INNER JOIN `ac_security_policy_items` `policy_item_chk_#{i}`
              ON `policy_item_chk_#{i}`.`role_id` = `roles_chk_#{i}`.`id`
              AND `policy_item_chk_#{i}`.`permission_name` = #{c.quote(p)}

          "
        end.strip.gsub(/\s+/, ' ')
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
