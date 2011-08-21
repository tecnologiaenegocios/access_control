require 'access_control/blockable'
require 'access_control/exceptions'
require 'access_control/grantable'
require 'access_control/inheritable'

module AccessControl

  class Restricter

    attr_reader :model

    def initialize(model)
      @model = model
    end

    def options(permissions, filter=nil)

      pk = model.primary_key
      inheritable_ids = Inheritable.new(model).ids_with(permissions)
      granted_ids = Grantable.new(model).ids_with(permissions, filter)
      blocked_ids = Blockable.new(model).ids
      table_id = "#{model.quoted_table_name}.#{pk}"

      if blocked_ids.any?
        { :conditions => [
          "#{table_id} IN (?) OR "\
            "(#{table_id} IN (?) AND #{table_id} NOT IN (?))",
          granted_ids, inheritable_ids, blocked_ids
        ]}
      else
        {:conditions => ["#{table_id} IN (?)", (granted_ids | inheritable_ids)]}
      end
    end

  end

end
