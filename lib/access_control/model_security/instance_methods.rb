require 'access_control/model_security/class_methods'
require 'access_control/configuration'
require 'access_control/node'
require 'access_control/security_manager'

module AccessControl
  module ModelSecurity
    module InstanceMethods

      def self.included base
        base.extend(ClassMethods)
        base.has_one :ac_node,
                     :as => :securable,
                     :class_name => Node.name,
                     :dependent => :destroy
        base.class_eval do
          alias_method_chain :destroy, :referenced_children
          alias_method_chain :destroy, :authorization
          class << self
            VALID_FIND_OPTIONS.push(:permissions, :load_permissions).uniq!
            alias_method_chain :find_every, :restriction
            alias_method_chain :find_one, :unauthorized
          end
        end
      end

      def parents
        return [] if self.class.inherits_permissions_from.empty?
        return [] unless AccessControl.config.tree_creation
        disable_query_restriction
        result = self.class.inherits_permissions_from.inject([]) do |r, a|
          r << send(a)
        end.flatten.compact.uniq
        re_enable_query_restriction
        result
      end

      def parents_for_creation
        normal_parents = parents
        return normal_parents if normal_parents.any?
        [AccessControlGlobalRecord.instance]
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

      def destroy_with_authorization
        verify_destroy_permissions
        destroy_without_authorization
      end

      private

        def create_nodes
          Node.create!(
            :securable => self, :parents => parents.map(&:ac_node)
          ) if self.class.securable?
        end

        def update_parent_nodes
          ac_node.parents = parents.map(&:ac_node) if ac_node
        end

        def update_child_nodes
          new_and_old_children.each do |children|
            children.each do |c|
              # Here we use unrestricted_find to make a reload of the child,
              # but without permission checking.
              c.class.unrestricted_find(c.id).send(:update_parent_nodes)
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
          disable_query_restriction
          old_children = []
          new_children = self.class.propagates_permissions_to.inject([]){|r, a|
            reflection = self.class.reflections[a.to_sym]
            if reflection.macro == :belongs_to
              old, new = changes[reflection.primary_key_name.to_s]
              old_children << reflection.klass.find(old) if old
            end
            r << send(a)
          }.flatten.compact.uniq
          re_enable_query_restriction
          [new_children, old_children]
        end

        def reparent_saved_referenced_children
          @old_children.each do |child|
            next unless child.ac_node
            child.ac_node.send(:disconnect_self_and_descendants_from_ancestors)
            child.parents.each do |new_parent|
              child.ac_node.parents << new_parent.ac_node
            end
          end
        end

        def verify_default_permissions?(type)
          self.class.securable? &&
            AccessControl.security_manager &&
            self.class.send(:"permissions_required_to_#{type}").any?
        end

        def verify_create_permissions
          return unless verify_default_permissions?('create')
          manager = AccessControl.security_manager
          parents_for_creation.each do |parent|
            manager.verify_access!(parent.ac_node,
                                   self.class.permissions_required_to_create)
          end
        end

        def verify_update_permissions
          return unless verify_default_permissions?('update')
          AccessControl.security_manager.verify_access!(
            self.ac_node, self.class.permissions_required_to_update
          )
        end

        def verify_destroy_permissions
          return unless verify_default_permissions?('destroy')
          AccessControl.security_manager.verify_access!(
            self.ac_node, self.class.permissions_required_to_destroy
          )
        end

    end
  end
end
