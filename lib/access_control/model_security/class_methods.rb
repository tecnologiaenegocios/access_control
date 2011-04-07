require 'access_control/configuration'
require 'access_control/exceptions'
require 'access_control/security_manager'
require 'access_control/permission_registry'
require 'access_control/util'

module AccessControl
  module ModelSecurity
    module ClassMethods

      def protect method_name, options
        PermissionRegistry.register(permissions = options[:with])
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
              raise InvalidInheritage,
                    "unexpected #{a} association to have :finder_sql option"
            end
            next if reflection.macro == :belongs_to
            if reflection.options[:conditions]
              raise InvalidInheritage,
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
              set_remove_hook_in_habtm(reflection)
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

      [:query, :view, :create, :update].each do |name|
        define_method(:"#{name}_requires") do |*permissions|
          instance_variable_set("@added_#{name}_requirements", Set.new)
          instance_variable_set("@declared_#{name}_requirements",
                                Util.make_set_from_args(*permissions))
        end

        define_method(:"declared_#{name}_requirements") do
          instance_variable_get("@declared_#{name}_requirements")
        end

        define_method(:"add_#{name}_requirement") do |*permissions|
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
          added = send("added_#{name}_requirements")
          declared = send("declared_#{name}_requirements")
          return declared | added if declared
          if superclass.respond_to?("permissions_required_to_#{name}")
            p = superclass.send("permissions_required_to_#{name}")
          else
            p = AccessControl.config.send("default_#{name}_permissions")
          end
          p | added
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
        object.class.check_inheritance! if object.class.securable?
        return object unless manager = AccessControl.get_security_manager
        reqs = Thread.current[:instantiation_requirements] || {}
        if reqs[self]
          context, permissions = reqs[self]
          reqs.delete self
          manager.verify_access!(context, permissions)
        end
        protect_methods!(object)
        object
      end

      def allocate *args
        object = super
        object.class.check_inheritance! if object.class.securable?
        return object unless manager = AccessControl.get_security_manager
        protect_methods!(object) if object.class.securable?
        object
      end

      def find_every_with_restriction(options)
        options[:permissions] ||= permissions_required_to_query
        if !options[:permissions].is_a?(Enumerable)
          raise ArgumentError, ':permissions must be an enumerable'
        end
        merge_permission_options(options)
        find_every_without_restriction(options)
      end

      def find_one_with_unauthorized(id, options)
        old_options = options.clone
        options[:permissions] ||= (
          permissions_required_to_view | permissions_required_to_query
        )
        begin
          return find_one_without_unauthorized(id, options)
        rescue ActiveRecord::RecordNotFound => e
          disable_query_restriction
          result = find_one_without_unauthorized(id, old_options) rescue nil
          re_enable_query_restriction
          raise e if !result
          Util.log_missing_permissions(result.ac_node, options[:permissions])
          raise Unauthorized
        end
      end

      def unrestricted_find(*args)
        disable_query_restriction
        result = find(*args)
        re_enable_query_restriction
        result
      end

      private

        def set_remove_hook_in_habtm reflection
          reflection.options[:after_remove] = Proc.new do |record, removed|
            removed.reload.send(:update_parent_nodes)
          end
          add_association_callbacks(reflection.name, reflection.options)
        end

        def protect_methods!(instance)
          manager = AccessControl.get_security_manager
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
          "DISTINCT #{references.join(', ')}"
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
  end
end
