require 'access_control/configuration'
require 'access_control/exceptions'
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

      def inherits_permissions_from *args
        if args.any?
          args.each do |a|
            reflection = reflections[a.to_sym]
            next if reflection.macro == :belongs_to
            next if reflection.macro == :has_and_belongs_to_many
            m = nil
            if reflection.options[:through]
              m = "unexpected #{a} association to have :through option"
            elsif reflection.options[:as]
              m = "unexpected #{a} association to have :as option"
            elsif reflection.macro == :composed_of
              m = "unexpected aggregation #{a}"
            end
            raise AccessControl::InvalidInheritage, m if m
          end
          @inherits_permissions_from = args
        end
        @inherits_permissions_from ||= []
      end

      def propagates_permissions_to *args
        if args.any?
          args.each do |a|
            reflection = reflections[a.to_sym]
            if reflection.macro == :has_and_belongs_to_many
              set_remove_hook_in_habtm(reflection)
              next
            end
            if reflection.macro == :belongs_to
              next if !reflection.options[:polymorphic]
              m = "unexpected #{a} to be polymorphic"
            else
              m = "expected #{a} to be a :belongs_to or habtm association"
            end
            raise AccessControl::InvalidPropagation, m
          end
          @propagates_permissions_to = args
        end
        @propagates_permissions_to ||= []
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

      def securable?
        true
      end

      private

        def set_remove_hook_in_habtm reflection
          reflection.options[:before_remove] = Proc.new do |record, removed|
            removed.send(:update_parent_nodes)
          end
          add_association_callbacks(reflection.name, reflection.options)
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
        return [] if self.class.inherits_permissions_from.empty?
        self.class.inherits_permissions_from.inject([]) do |r, a|
          r << send(a)
        end.flatten.compact.uniq
      end

      def children
        return [] if self.class.propagates_permissions_to.empty?
        self.class.propagates_permissions_to.inject([]) do |r, a|
          reflection = self.class.reflections[a.to_sym]
          if reflection.macro == :belongs_to
            old, new = changes[reflection.primary_key_name.to_s]
            old_children_objects << reflection.klass.find(old) if old
          end
          r << send(a)
        end.flatten.compact.uniq
      end

      def old_children_objects
        @old_children_objects ||= []
      end

      private

        def create_nodes
          AccessControl::Model::Node.create!(
            :securable => self, :parents => parents.map(&:ac_node)
          ) if self.class.securable?
        end

        def update_parent_nodes
          ac_node.parents = parents.map(&:ac_node) if ac_node
        end

        def update_child_nodes
          children.each do |child|
            child.send(:update_parent_nodes)
          end
          old_children_objects.each do |child|
            child.send(:update_parent_nodes)
          end
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

  end
end

class ActiveRecord::Base

  include AccessControl::ModelSecurity::InstanceMethods

  class << self

    VALID_FIND_OPTIONS.push(:permissions, :load_permissions).uniq!

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
        options[:select] = \
          prefix_with_distinct_and_table_name(options[:select] || '*')
      end

      def prefix_with_distinct_and_table_name(select_clause)
        references = []
        select_clause.strip!
        if !(select_clause =~ /^distinct\s+/i)
          references << "#{quoted_table_name}.`#{primary_key}`"
        end
        select_clause.gsub(/^distinct\s+/i, '').split(',').each do |token|
          t = token.strip.gsub('`', '')
          next references << "#{quoted_table_name}.*" if t == '*'
          if columns_hash.keys.include?(t)
            next references << "#{quoted_table_name}.`#{t}`"
          end
          # Functions or other references are not prefixed.
          references << token
        end
        "DISTINCT #{references.uniq.join(', ')}"
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
  after_save :update_child_nodes
  before_validation :disable_query_restriction
  after_validation :re_enable_query_restriction

end
