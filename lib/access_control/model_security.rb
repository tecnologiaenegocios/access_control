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
            if reflection.options[:finder_sql]
              raise AccessControl::InvalidInheritage,
                    "unexpected #{a} association to have :finder_sql option"
            end
            next if reflection.macro == :belongs_to
            if reflection.options[:conditions]
              raise AccessControl::InvalidInheritage,
                    "unexpected #{a} association to have :conditions option"
            end
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
            if reflection.options[:conditions]
              raise AccessControl::InvalidPropagation,
                    "unexpected #{a} association to have :conditions option"
            elsif reflection.options[:finder_sql]
              raise AccessControl::InvalidPropagation,
                    "unexpected #{a} association to have :finder_sql option"
            end
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

      def check_inheritance!

        return true if @already_checked_inheritance

        inherits_permissions_from.each do |a1|
          reflection = reflections[a1.to_sym]
          klass = reflection.klass
          case reflection.macro
          when :has_many, :has_one
            inverse_key = reflection.primary_key_name.to_s
            unless klass.propagates_permissions_to.any? do |a2|
              klass.reflections[a2.to_sym].klass == self &&
              klass.reflections[a2.to_sym].primary_key_name.to_s == inverse_key
            end
              raise AccessControl::MissingPropagation,
                    "#{klass.name} missing propagation to #{name}."
            end
          when :has_and_belongs_to_many
            assoc_key = reflection.primary_key_name.to_s
            inverse_key = reflection.association_foreign_key.to_s
            join_table = reflection.options[:join_table].to_s
            unless klass.propagates_permissions_to.any? do |a2|
              other_ref = klass.reflections[a2.to_sym]
              other_ref.klass == self &&
              other_ref.primary_key_name.to_s == inverse_key &&
              other_ref.association_foreign_key.to_s == assoc_key &&
              other_ref.options[:join_table].to_s == join_table
            end
              raise AccessControl::MissingPropagation,
                    "#{klass.name} missing propagation to #{name}."
            end
          end
        end

        @already_checked_inheritance = true
      end

      private

        def set_remove_hook_in_habtm reflection
          reflection.options[:after_remove] = Proc.new do |record, removed|
            removed.reload.send(:update_parent_nodes)
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
          alias_method_chain :destroy, :referenced_children
        end
      end

      def parents
        return [] if self.class.inherits_permissions_from.empty?
        return [] unless AccessControl.config.tree_creation
        self.class.inherits_permissions_from.inject([]) do |r, a|
          r << send(a)
        end.flatten.compact.uniq
      end

      def children
        new_and_old_children.first
      end

      def destroy_with_referenced_children
        @old_children ||= []
        if ac_node
          @old_children = ac_node.children.map(&(:securable.to_proc))
        end
        destroy_without_referenced_children
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
          new_and_old_children.each do |children|
            children.each do |child|
              child.reload.send(:update_parent_nodes)
            end
          end
        end

        def disable_query_restriction
          self.class.send(:disable_query_restriction)
          # This must return true or else validation stops and the record ends
          # being considered invalid.
          true
        end

        def re_enable_query_restriction
          self.class.send(:re_enable_query_restriction)
        end

        def new_and_old_children
          return [[], []] if self.class.propagates_permissions_to.empty?
          return [[], []] unless AccessControl.config.tree_creation
          old_children = []
          new_children = self.class.propagates_permissions_to.inject([]){|r, a|
            reflection = self.class.reflections[a.to_sym]
            if reflection.macro == :belongs_to
              old, new = changes[reflection.primary_key_name.to_s]
              old_children << reflection.klass.find(old) if old
            end
            r << send(a)
          }.flatten.compact.uniq
          [new_children, old_children]
        end

        def reparent_saved_referenced_children
          @old_children.each do |child|
            child.ac_node.send(:disconnect_self_and_descendants_from_ancestors)
            child.parents.each do |new_parent|
              child.ac_node.parents << new_parent.ac_node
            end
          end
        end

    end

  end
end

class ActiveRecord::Base

  include AccessControl::ModelSecurity::InstanceMethods

  class << self

    VALID_FIND_OPTIONS.push(:permissions, :load_permissions).uniq!

    def new_with_security *args
      object = new_without_security *args
      return object unless manager = AccessControl.get_security_manager
      return object unless object.class.securable?
      object.class.check_inheritance!
      AccessControl::SecurityProxy.new(object)
    end

    alias_method_chain :new, :security

    def allocate_with_security *args
      object = allocate_without_security *args
      return object unless manager = AccessControl.get_security_manager
      return object unless object.class.securable?
      object.class.check_inheritance!
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
  after_destroy :reparent_saved_referenced_children

end
