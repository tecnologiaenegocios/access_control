require 'access_control/orm/active_record_class'
require 'access_control/orm/sequel_class'

module AccessControl
  module ORM
    def self.adapt_class(object)
      if object <= ActiveRecord::Base
        ActiveRecordClass.new(object)
      elsif object <= Sequel::Model
        SequelClass.new(object)
      end
    end
  end
end
