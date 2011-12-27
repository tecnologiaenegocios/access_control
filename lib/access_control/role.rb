require 'access_control/ids'

module AccessControl
  class Role < ActiveRecord::Base

    extend AccessControl::Ids

    set_table_name :ac_roles
    has_many :security_policy_items,
             :dependent => :destroy,
             :class_name => 'AccessControl::SecurityPolicyItem'

    # This association is not marked as `:dependent => :destroy` because the
    # destruction of the dependent items is done explicitly in a callback
    # below.
    has_many :assignments,
             :class_name => 'AccessControl::Assignment'

    validates_presence_of :name
    validates_uniqueness_of :name

    before_destroy :destroy_dependant_assignments

    named_scope :local_assignables,
                :conditions => {:local => true}

    named_scope :global_assignables,
                :conditions => {:global => true}

    named_scope :for_permission, lambda {|permission|
      ids = SecurityPolicyItem.with_permission(permission).role_ids
      { :conditions => { :id => ids } }
    }

    def self.default
      with_names_in(AccessControl.config.default_roles)
    end

    def self.with_names_in(names)
      unless names.kind_of?(String) || names.kind_of?(Array)
        names = names.to_a
      end
      scoped_by_name(names)
    end

    def permissions
      Set.new(security_policy_items.map(&:permission))
    end

    def assign_to(user, options={})
      principal, node = assignment_parameters(user, options)
      assignments.find_or_create_by_principal_id_and_node_id(principal.id,
                                                             node.id)
    end

    def assigned_to?(user, options={})
      principal, node = assignment_parameters(user, options)
      assignments.exists?(:principal_id => principal, :node_id => node)
    end

    def assign_permission(permission)
      unless security_policy_items.find_by_permission(permission)
        security_policy_items.create!(:permission => permission)
      end
    end

  private

    def destroy_dependant_assignments
      AccessControl.manager.without_assignment_restriction do
        assignments.each do |assignment|
          assignment.destroy
        end
      end
    end

    def assignment_parameters(user, options)
      principal = user.ac_principal
      if context = options[:at]
        node = Context.new(context).nodes.first
      else
        node = AccessControl.global_node
      end
      [principal, node]
    end
  end
end
