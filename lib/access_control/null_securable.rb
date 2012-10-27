require 'access_control/null_restriction'

module AccessControl
  module NullSecurable

    def self.included(base)
      base.extend(ClassMethods)

      if base < ActiveRecord::Base
        base.class_eval do
          include AccessControl::NullRestriction
        end
      end
    end

    module ClassMethods

      # AccessControl::Macros

      [:show, :list, :create, :update, :destroy].each do |t|
        define_method(:"#{t}_requires") { |*args, &block| }
        define_method(:"add_#{t}_requirement") { |*args, &block| }
        define_method(:"permissions_required_to_#{t}") do |*args, &block|
          Set.new
        end
      end

      def define_unrestricted_method *args, &block
      end

      def unrestrict_method *args, &block
      end

      # AccessControl::MethodProtection

      def protect *args, &block
      end

      # AccessControl::Inheritance

      def inherits_permissions_from(*args, &block)
      end

      def inherits_permissions_from_association(*args, &block)
      end
    end
  end
end
