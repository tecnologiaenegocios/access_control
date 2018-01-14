require 'delegate'
require 'access_control/orm'
require 'access_control/selectable'

module AccessControl
  module Restriction

    class << self
      def included(base)
        base.extend(ClassMethods)
      end

      def listing_condition_for(target)
        subquery_sql = Selectable.new(target).subquery_sql do |type|
          type.permissions_required_to_list
        end

        return unless subquery_sql

        column = "#{target.quoted_table_name}.#{target.primary_key}"
        "#{column} IN (#{subquery_sql})"
      end
    end

    def valid?
      AccessControl.manager.without_query_restriction { super }
    end

    module ClassMethods

      def find(*args)
        return super unless AccessControl.manager.restrict_queries?
        return super if scope(:find, :ac_unrestrict)
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
        return super if scope(:find, :ac_unrestrict)
        with_listing_filtering { super }
      end

      def listable
        return scoped({}) unless AccessControl.manager.restrict_queries?
        scoped(:conditions => Restriction.listing_condition_for(self))
      end

      def unrestricted_find(*args)
        AccessControl.manager.without_query_restriction { find(*args) }
      end

      def belongs_to(name, *)
        super

        alias_method :"restricted_#{name}", name

        # For simmetry with restricted has_one, restricted belongs_to returns
        # `nil' when the associated record is unaccessible.  Restricted has_one
        # is just a special case of restricted has_many, and that's why it
        # doesn't fail with Unauthorized and just returns nil (it's like
        # [].first).
        prepend (Module.new do
          define_method(:"restricted_#{name}") do |*args|
            begin
              super(*args)
            rescue Unauthorized
            end
          end
        end)

        prepend (Module.new do
          define_method(name) do |*args|
            AccessControl.manager.without_query_restriction { super(*args) }
          end
        end)
      end

      def has_one(name, *)
        super

        alias_method :"restricted_#{name}", name

        prepend (Module.new do
          define_method(name) do |*args|
            AccessControl.manager.without_query_restriction { super(*args) }
          end
        end)
      end

      def has_many(name, *)
        super

        alias_method :"restricted_#{name}", name

        prepend (Module.new do
          define_method(name) do |*args|
            proxy = AccessControl.manager.without_query_restriction do
              super(*args)
            end
            proxy.proxy_extend(CollectionAssociationUnrestriction)
            proxy
          end
        end)
      end

      def has_and_belongs_to_many(name, *)
        super

        alias_method :"restricted_#{name}", name

        prepend (Module.new do
          define_method(name) do |*args|
            proxy = AccessControl.manager.without_query_restriction do
              super(*args)
            end
            proxy.proxy_extend(CollectionAssociationUnrestriction)
            proxy
          end
        end)
      end

      def preload_associations(*)
        AccessControl.manager.without_query_restriction { super }
      end

    private

      def with_listing_filtering
        condition = Restriction.listing_condition_for(self)
        with_scope(:find => { :conditions => condition }) { yield }
      end
    end

    module CollectionAssociationUnrestriction
      def construct_find_options!(options)
        super(options)
        options.merge!(ac_unrestrict: true)
      end

      def construct_scope(*args)
        super.tap do |hash|
          hash[:find].merge!(ac_unrestrict: true)
        end
      end

      def find(*args, &block)
        AccessControl.manager.without_query_restriction { super }
      end

      def all(*args, &block)
        AccessControl.manager.without_query_restriction { super }
      end
    end
  end
end

class ActiveRecord::Base
  class << self
    VALID_FIND_OPTIONS << :ac_unrestrict
  end
end
