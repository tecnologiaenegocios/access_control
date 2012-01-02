require 'access_control/ids'
require 'access_control/manager'

module AccessControl
  class Assignment < ActiveRecord::Base

    extend AccessControl::Ids

    set_table_name :ac_assignments

    belongs_to :role, :class_name => 'AccessControl::Role'

    has_many :security_policy_items, :through => :role

    named_scope :granting, lambda {|permission|
      ids = Role.for_permission(permission).ids
      { :conditions => { :role_id => ids } }
    }

    def self.with_roles(roles)
      roles = Util.ids_for_hash_condition(roles)
      scoped(:conditions => { :role_id => roles })
    end

    def self.assigned_to(principal)
      principal = Util.ids_for_hash_condition(principal)
      scoped(:conditions => { :principal_id => principal })
    end

    def self.with_nodes(nodes)
      node_id = Util.ids_for_hash_condition(nodes)
      scoped(:conditions => { :node_id => node_id })
    end

    def self.granting_for_principal(permission, principal)
      granting(permission).assigned_to(principal)
    end

    def self.overlapping(roles_ids, principals_ids, nodes_ids)
      with_roles(roles_ids).
        assigned_to(principals_ids).
        with_nodes(nodes_ids)
    end

    def node=(node)
      self.node_id = node.id
      @node        = node
    end

    def node
      @node ||= Node.fetch(node_id, nil)
    end

    def principal=(principal)
      self.principal_id = principal.id
      @principal        = principal
    end

    def principal
      @principal ||= Principal.fetch(principal_id, nil)
    end

    def overlaps?(other)
      other.node_id == node_id && other.role_id == role_id &&
        other.principal_id == principal_id
    end

  end
end
