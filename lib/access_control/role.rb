module AccessControl
  class Role < ActiveRecord::Base
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

    named_scope :local_assignables,
                :conditions => {:local => true}

    named_scope :global_assignables,
                :conditions => {:global => true}

    def permissions
      Set.new(security_policy_items.map(&:permission))
    end

    def assign_to(user, options={})
      principal = user.ac_principal
      if context = options[:at]
        node = Context.new(context).nodes.first
      else
        node = Node.global
      end
      assignments.create!(
        :principal => principal,
        :node => node
      )
    end

    before_destroy :destroy_dependant_assignments

  private

    def destroy_dependant_assignments
      AccessControl.manager.without_assignment_restriction do
        assignments.each do |assignment|
          assignment.destroy
        end
      end
    end
  end
end
