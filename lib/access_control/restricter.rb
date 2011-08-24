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
      if !grantable.from_class?(permissions)
        granted_ids = grantable.ids_with(permissions)
        inherited_ids = Inheritable.new(model).ids_with(permissions)
        ids = (inherited_ids - blocked_ids) | granted_ids
        ids = (Set.new(filter) & ids) if filter
        { :conditions => ["#{table_id} IN (?)", ids.to_a] }
      else
        if blocked_ids.any?
          ids = (blocked_ids - grantable.ids_with(permissions)).to_a
          { :conditions => ["#{table_id} NOT IN (?)", ids] }
        else
          filter ? { :conditions => ["#{table_id} IN (?)", filter] } : {}
        end
      end
    end

  private

    def grantable
      @grantable ||= Grantable.new(model)
    end

    def blocked_ids
      @blocked_ids ||= Blockable.new(model).ids
    end

    def table_id
      @table_id ||= "#{model.quoted_table_name}.#{model.primary_key}"
    end

  end

end
