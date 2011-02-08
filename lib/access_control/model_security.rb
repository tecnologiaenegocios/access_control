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

    end

    module InstanceMethods

      def self.included base
        base.extend(ClassMethods)
        base.has_one :ac_node, :as => :securable,
                     :class_name => ::AccessControl::Model::Node.name
        base.class_eval do
          def ac_node_with_automatic_creation
            return if new_record?
            current_node = ac_node_without_automatic_creation
            return current_node if current_node
            _create_nodes
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

  after_create :_create_nodes
  def _create_nodes
    AccessControl::Model::Node.create!(
      :securable => self, :parents => parents.map(&:ac_node)
    ) if securable?
  end

  after_update :_update_parent_nodes
  def _update_parent_nodes
    ac_node.parents = parents.map(&:ac_node) if ac_node
  end

  def securable?
    true
  end

  include AccessControl::ModelSecurity::InstanceMethods

  class << self
    def allocate_with_security *args
      object = allocate_without_security *args
      return object unless manager = AccessControl.get_security_manager
      return object unless object.securable?
      AccessControl::SecurityProxy.new(object)
    end
    alias_method_chain :allocate, :security
  end

end
