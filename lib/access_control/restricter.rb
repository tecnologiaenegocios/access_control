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
      inherited_ids = Inheritable.new(model).ids_with(permissions)
      granted_ids = Grantable.new(model).ids_with(permissions, filter)
      blocked_ids = Blockable.new(model).ids
      ids = ((inherited_ids - blocked_ids) | granted_ids).to_a
      table_id = "#{model.quoted_table_name}.#{pk}"
      { :conditions => ["#{table_id} IN (?)", ids] }
    end

  end

end
