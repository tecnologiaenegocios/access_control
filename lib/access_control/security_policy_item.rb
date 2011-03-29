module AccessControl
  class SecurityPolicyItem < ActiveRecord::Base

    set_table_name :ac_security_policy_items
    belongs_to :role, :class_name => Role.name

    def self.securable?
      false
    end

    def self.mass_manage!(params)
      params ||= {}
      params = params.values if params.is_a?(Hash)
      params.each do |attributes|
        attributes = attributes.with_indifferent_access
        id = attributes.delete(:id)
        destroy = param_to_boolean(attributes.delete(:_destroy))
        if id
          item = find(id)
          next item.destroy if destroy
          next item.update_attributes!(attributes)
        end
        create!(attributes) unless destroy
      end
    end

    private

      def self.param_to_boolean param
        case param
        when 0, '0', 'false', '', false, nil
          false
        else
          true
        end
      end

  end
end
