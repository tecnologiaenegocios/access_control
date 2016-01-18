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

      # Associations are unrestricted.  Note that this unrestriction only
      # extends to the result of their reader method (which either return an
      # object from another model or an association proxy), not to methods
      # called upon (which in turn can be secured independently).
      #
      # The main motivation for this is that for the final user it's rather
      # difficult, almost impossible, to guess which association the current
      # user lacks permissions and is being called triggering an unauthorized
      # error, unintended by the programmers (like seeing the name of another
      # user, an information of users' profiles which may be not generally
      # available for any other then the user itself, but some info, like its
      # name, is allowed to be public).  Another motivation is that we already
      # don't check create-, destroy- and update- permissions during
      # save/destroy beyond the first call.  Since we already do so, it's not
      # helpful to check show- and list- on association load.
      def has_one(name, *args)
        super
        AccessControl.unrestrict_method(self, name)
      end

      def has_many(name, *args)
        super
        AccessControl.unrestrict_method(self, name)
      end

      def has_and_belongs_to_many(name, *args)
        super
        AccessControl.unrestrict_method(self, name)
      end

      def belongs_to(name, *args)
        super
        AccessControl.unrestrict_method(self, name)
      end

    private

      def with_listing_filtering
        condition = Restriction.listing_condition_for(self)
        with_scope(:find => { :conditions => condition }) { yield }
      end
    end
  end
end
