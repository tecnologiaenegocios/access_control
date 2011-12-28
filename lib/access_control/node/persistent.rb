require 'access_control/node'

module AccessControl
  class Node::Persistent < ActiveRecord::Base
    set_table_name 'ac_nodes'

    extend AccessControl::Ids

    named_scope :with_type, lambda {|securable_type| {
      :conditions => { :securable_type => securable_type }
    }}

    named_scope :blocked,   :conditions => { :block => true }
    named_scope :unblocked, :conditions => { :block => false }

    def self.granted_for(securable_type, principals, permissions)
      with_type(securable_type).with_ids(
        Assignment.granting_for_principal(permissions, principals).node_ids
      )
    end

    def self.blocked_for(securable_type)
      blocked.with_type(securable_type)
    end

  end
end
