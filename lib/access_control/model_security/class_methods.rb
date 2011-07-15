require 'access_control/configuration'
require 'access_control/exceptions'
require 'access_control/security_manager'
require 'access_control/permission_registry'
require 'access_control/util'

module AccessControl
  module ModelSecurity
    module ClassMethods

      def protect method_name, options
        PermissionRegistry.register(
          permissions = options[:with],
          :model => self.name,
          :method => method_name.to_s
        )
        permissions_for_methods[method_name.to_s].merge(permissions)
      end

      def permissions_for method_name
        permissions_for_methods[method_name.to_s]
      end

      def permissions_for_methods
        @ac_permissions_for_methods ||= Hash.new{|h, k| h[k] = Set.new}
      end

      def restrict_association association_name
        restricted_associations.add(association_name)
      end

      def restrict_all_associations!
        reflections.each do |name, reflection|
          if reflection.macro == :belongs_to
            restricted_associations.add(name.to_sym)
          end
        end
      end

      def unrestrict_association association_name
        restricted_associations.delete(association_name)
      end

      def unrestrict_all_associations!
        restricted_associations.clear
      end

      def association_restricted? association_name
        restricted_associations.include?(association_name)
      end

      def restricted_associations
        return @ac_restricted_associations if @ac_restricted_associations
        restricted_associations = Set.new
        if AccessControl.config.restrict_belongs_to_association
          reflections.each do |name, reflection|
            if reflection.macro == :belongs_to
              restricted_associations.add(name.to_sym)
            end
          end
        end
        @ac_restricted_associations = restricted_associations
      end

      def inherits_permissions_from *args
        if args.any?
          args.each do |a|
            reflection = reflections[a.to_sym]
            if reflection.options[:finder_sql]
              raise InvalidInheritage,
                    "unexpected #{a} association to have :finder_sql option"
            end
            next if reflection.macro == :belongs_to
            if reflection.options[:conditions]
              raise InvalidInheritage,
                    "unexpected #{a} association to have :conditions option"
            end
            if reflection.macro == :has_and_belongs_to_many
              set_remove_hook_for_parent_in_habtm(reflection)
              set_add_hook_for_parent_in_habtm(reflection)
              next
            end
            m = nil
            if reflection.options[:through]
              m = "unexpected #{a} association to have :through option"
            elsif reflection.options[:as]
              m = "unexpected #{a} association to have :as option"
            elsif reflection.macro == :composed_of
              m = "unexpected aggregation #{a}"
            end
            raise InvalidInheritage, m if m
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
              raise InvalidPropagation,
                    "unexpected #{a} association to have :conditions option"
            elsif reflection.options[:finder_sql]
              raise InvalidPropagation,
                    "unexpected #{a} association to have :finder_sql option"
            end
            if reflection.macro == :has_and_belongs_to_many
              set_remove_hook_for_children_in_habtm(reflection)
              set_add_hook_for_children_in_habtm(reflection)
              next
            end
            if reflection.macro == :belongs_to
              next if !reflection.options[:polymorphic]
              m = "unexpected #{a} to be polymorphic"
            else
              m = "expected #{a} to be a :belongs_to or habtm association"
            end
            raise InvalidPropagation, m
          end
          @propagates_permissions_to = args
        end
        @propagates_permissions_to ||= []
      end

      [:query, :view, :create, :update, :destroy].each do |name|

        define_method(:"#{name}_requires") do |*permissions|
          if permissions == [:none]
            permissions = Set.new
            instance_variable_set("@declared_no_permissions_to_#{name}", true)
          else
            instance_variable_set("@declared_no_permissions_to_#{name}", false)
          end
          args_to_register = permissions.dup + [{
            :action => name.to_s,
            :model => self.name
          }]
          PermissionRegistry.register(*args_to_register)
          instance_variable_set("@added_#{name}_requirements", Set.new)
          instance_variable_set("@declared_#{name}_requirements",
                                Util.make_set_from_args(*permissions))
        end

        define_method(:"declared_#{name}_requirements") do
          instance_variable_get("@declared_#{name}_requirements")
        end

        define_method(:"add_#{name}_requirement") do |*permissions|
          args_to_register = permissions.dup + [{
            :action => name.to_s,
            :model => self.name
          }]
          PermissionRegistry.register(*args_to_register)
          current = send("added_#{name}_requirements")
          Util.make_set_from_args(*permissions).each{|e| current.add(e)}
        end

        define_method(:"added_#{name}_requirements") do
          unless v = instance_variable_get("@added_#{name}_requirements")
            v = instance_variable_set("@added_#{name}_requirements", Set.new)
          end
          v
        end

        define_method(:"permissions_required_to_#{name}") do
          return Set.new if \
            instance_variable_get("@declared_no_permissions_to_#{name}")
          added = send("added_#{name}_requirements")
          declared = send("declared_#{name}_requirements") || Set.new
          return declared | added if declared.any?
          if superclass.respond_to?("permissions_required_to_#{name}")
            p = superclass.send("permissions_required_to_#{name}") \
              rescue Set.new
          else
            p = AccessControl.config.send("default_#{name}_permissions")
          end
          result = p | added
          raise AccessControl::NoPermissionsDeclared if (
            result.empty? && securable? &&
            AccessControl.model_security_strict?
          )
          result
        end

      end

      def set_temporary_instantiation_requirement context, permissions
        reqs = (Thread.current[:instantiation_requirements] ||= {})
        reqs[self] = [context, permissions]
      end

      def drop_all_temporary_instantiation_requirements!
        Thread.current[:instantiation_requirements] = {}
      end

      def securable?
        true
      end

      def check_inheritance!

        return if @already_checked_inheritance

        inherits_permissions_from.each do |a1|
          reflection = reflections[a1.to_sym]
          next if reflection.macro == :belongs_to
          klass = reflection.klass
          case reflection.macro
          when :has_many, :has_one
            inverse_key = reflection.primary_key_name.to_s
            unless klass.propagates_permissions_to.any? do |a2|
              klass.reflections[a2.to_sym].klass == self &&
              klass.reflections[a2.to_sym].primary_key_name.to_s == inverse_key
            end
              raise MissingPropagation,
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
              raise MissingPropagation,
                    "#{klass.name} missing propagation to #{name}."
            end
          end
        end

        @already_checked_inheritance = true
      end

      def new *args
        object = super
        if object.class.securable?
          object.class.check_inheritance!
          reqs = Thread.current[:instantiation_requirements] || {}
          if reqs[self]
            context, permissions = reqs[self]
            reqs.delete self
            AccessControl.security_manager.verify_access!(context, permissions)
          end
          protect_methods!(object)
        end
        object
      end

      def allocate *args
        object = super
        if object.class.securable?
          object.class.check_inheritance!
          protect_methods!(object)
        end
        object
      end

      def find_every_with_restriction(options)
        find_every_without_restriction(Restricter.new(self, options).
                                       restricted_options)
      end

      def find_one_with_unauthorized(id, options)
        permissions = options[:permissions] || permissions_required_to_view
        options[:permissions] = Set.new
        result = find_one_without_unauthorized(id, options)
        if AccessControl.security_manager.restrict_queries?
          AccessControl.security_manager.verify_access!(result, permissions)
        end
        result
      end

      def unrestricted_find(*args)
        options = args.extract_options!
        options[:permissions] = Set.new
        find(*(args.push(options)))
      end

    private

      def set_add_hook_for_children_in_habtm reflection
        reflection.options[:after_add] = Proc.new do |record, added|
          added.reload.send(:update_parent_nodes)
        end
        add_association_callbacks(reflection.name, reflection.options)
      end

      def set_add_hook_for_parent_in_habtm reflection
        reflection.options[:after_add] = Proc.new do |record, added|
          record.send(:update_parent_nodes)
        end
        add_association_callbacks(reflection.name, reflection.options)
      end

      def set_remove_hook_for_children_in_habtm reflection
        reflection.options[:after_remove] = Proc.new do |record, removed|
          removed.reload.send(:update_parent_nodes)
        end
        add_association_callbacks(reflection.name, reflection.options)
      end

      def set_remove_hook_for_parent_in_habtm reflection
        reflection.options[:after_remove] = Proc.new do |record, removed|
          record.send(:update_parent_nodes)
        end
        add_association_callbacks(reflection.name, reflection.options)
      end

      def protect_methods!(instance)
        manager = AccessControl.security_manager
        permissions_for_methods.keys.each do |m|
          (class << instance; self; end;).class_eval do
            define_method(m) do
              nodes = ac_node || parents_for_creation.map(&:ac_node)
              manager.verify_access!(nodes,
                                     self.class.permissions_for(__method__))
              super
            end
          end
        end
      end

      class Restricter

        attr_reader :model, :options

        def initialize(model, options)
          @model = model
          @options = options
        end

        def restricted_options
          merge_permission_options!
          options
        end

      private

        def merge_permission_options!
          if AccessControl.security_manager.restrict_queries? &&
             !on_validation? &&
             model.securable?
            add_permissions!
            restrict_ids!
          end
          merge_permission_includes!
        end

        def add_permissions!
          options[:permissions] ||= model.permissions_required_to_query
          if !options[:permissions].is_a?(Enumerable)
            raise ArgumentError, ':permissions must be an enumerable'
          end
        end

        def restrict_ids!
          return unless options[:permissions].any?
          ids_options = options.dup
          merge_permission_joins(ids_options)
          ids_options[:select] = "#{model.quoted_table_name}."\
                                 "`#{model.primary_key}`"
          ids = model.send(:find_every_without_restriction,
                           ids_options).map(&:id)
          if options[:conditions]
            options[:conditions] = model.send(:merge_conditions,
              options[:conditions], {:id => ids}
            )
          else
            options[:conditions] = {:id => ids}
          end
        end

        def merge_permission_joins(options)
          if options[:joins]
            options[:joins] = model.send(:merge_joins,
              options[:joins],
              joins_for_permissions(options)
            )
          else
            options[:joins] = joins_for_permissions(options)
          end
        end

        def merge_permission_includes!
          options[:include] = model.send(:merge_includes,
            options[:include],
            includes_for_permissions(options)
          ) if options[:load_permissions]
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

          c = model.connection
          t = model.table_name
          pk = model.primary_key
          principal_ids = AccessControl.security_manager.principal_ids

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
              AND `nodes_chk_#{i}`.`securable_type` = #{c.quote(model.name)}

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
                AND `policy_item_chk_#{i}`.`permission` = #{c.quote(p)}

            "
          end.strip.gsub(/\s+/, ' ')
        end

        def on_validation?
          (Thread.current[:validation_chain_depth] || 0) > 0
        end

      end

    end
  end
end
