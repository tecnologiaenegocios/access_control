require 'access_control/orm'
require 'access_control/restricter'

module AccessControl
  module Restriction

    class << self
      def included(base)
        base.extend(ClassMethods)
      end

      def listing_condition_for(target)
        column = "#{target.quoted_table_name}.#{target.primary_key}"

        all_types = target.instance_eval do
          break @__AccessControl_Restriction_self_and_subclasses__ ||=
            ObjectSpace.each_object(target.singleton_class).select do |s|
              # Instance singleton classes must not be returned.  They are
              # exposed in Ruby 2.3+.  Ignore all singleton classes as well.
              !s.singleton_class?
            end
        end

        subqueries = all_types.map do |type|
          restricter  = Restricter.new(ORM.adapt_class(type))
          permissions = type.permissions_required_to_list

          restricter.sql_query_for(permissions)
        end

        "#{column} IN (#{subqueries.join(" UNION ALL ")})"
      end
    end

    def valid?
      AccessControl.manager.without_query_restriction { super }
    end

    module ClassMethods

      def find(*args)
        return super unless AccessControl.manager.restrict_queries?
        case args.first
        when :all, :last, :first
          with_listing_filtering { super }
        else
          permissions = permissions_required_to_show
          manager = AccessControl.manager
          results = super(*args)
          test_results = Array(results)
          test_results.each { |result| manager.can!(permissions, result) }
          results
        end
      end

      def calculate(*args)
        return super unless AccessControl.manager.restrict_queries?
        with_listing_filtering { super }
      end

      def listable
        return scoped({}) unless AccessControl.manager.restrict_queries?
        scoped(:conditions => Restriction.listing_condition_for(self))
      end

      def unrestricted_find(*args)
        AccessControl.manager.without_query_restriction { find(*args) }
      end

      # For simmetry with has_one, belongs_to returns `nil' when the associated
      # record is unaccessible.  Collection associations will be filtered by
      # default. has_one is just a special case of has_many, and that's why it
      # doesn't fail with Unauthorized and just returns nil (it's like
      # [].first).
      def belongs_to(name, *)
        super

        prepend (Module.new {
          define_method(name) do |*args|
            begin
              super(*args)
            rescue Unauthorized
            end
          end
        })
      end

    private

      def with_listing_filtering
        condition = Restriction.listing_condition_for(self)
        with_scope(:find => { :conditions => condition }) { yield }
      end
    end
  end
end
