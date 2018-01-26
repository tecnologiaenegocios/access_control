require 'delegate'
require 'access_control/orm'
require 'access_control/selectable'

module AccessControl
  module Restriction
    class << self
      def included(base)
        base.extend(ClassMethods)
      end

      def listing_condition_for(target, filter = nil)
        subquery_sql = Selectable.new(target).subquery_sql(filter) do |type|
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
        options = args.last.is_a?(Hash) ? args.last : {}

        if %i(all last first).include?(args.first)
          return with_listing_filtering(options) { super }
        end

        super.tap do |results|
          Array(results).each do |r|
            permissions = r.class.permissions_required_to_show
            AccessControl.manager.can!(permissions, r)
          end
        end
      end

      def calculate(*args)
        return super unless AccessControl.manager.restrict_queries?
        return super if scope(:find, :ac_unrestrict)
        options = args.last.is_a?(Hash) ? args.last : {}
        with_listing_filtering(options) { super }
      end

      def listable
        return scoped({}) unless AccessControl.manager.restrict_queries?
        scoped(conditions: Restriction.listing_condition_for(self))
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
        prepend(Module.new do
          define_method(:"restricted_#{name}") do |*args|
            begin
              super(*args)
            rescue Unauthorized
            end
          end
        end)

        prepend(Module.new do
          define_method(name) do |*args|
            AccessControl.manager.without_query_restriction { super(*args) }
          end
        end)
      end

      def has_one(name, *)
        super

        alias_method :"restricted_#{name}", name

        prepend(Module.new do
          define_method(name) do |*args|
            AccessControl.manager.without_query_restriction { super(*args) }
          end
        end)
      end

      def has_many(name, *)
        super

        define_method(:"restricted_#{name}") do |*args|
          public_send(name).listable
        end
      end

      def has_and_belongs_to_many(name, *)
        super

        define_method(:"restricted_#{name}") do |*args|
          public_send(name).listable
        end
      end

      def preload_associations(*)
        AccessControl.manager.without_query_restriction { super }
      end

    private

      def with_listing_filtering(**options)
        current_scope = with_scope(find: options) { break scope(:find) }
        current_conditions = current_scope[:conditions]
        if current_scope[:ac_safe_conditions] || current_conditions.is_a?(Hash)
          filter =
            if current_conditions.is_a?(Hash) &&
               current_conditions.keys.map(&:to_s) == [primary_key]
              current_conditions[primary_key] ||
                current_conditions[primary_key.to_sym]
            elsif current_conditions
              [Sequel.lit(with_exclusive_scope do
                break construct_finder_sql(select: primary_key,
                                           conditions: current_conditions)
              end)]
            end
        end
        condition = Restriction.listing_condition_for(self, filter)
        with_scope(find: { conditions: condition }) { yield }
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

class ActiveRecord::Associations::HasManyAssociation
  prepend AccessControl::Restriction::CollectionAssociationUnrestriction
end

class ActiveRecord::Associations::HasAndBelongsToManyAssociation
  prepend AccessControl::Restriction::CollectionAssociationUnrestriction
end

class ActiveRecord::Associations::HasManyThroughAssociation
  prepend AccessControl::Restriction::CollectionAssociationUnrestriction
end

class ActiveRecord::Base
  class << self
    VALID_FIND_OPTIONS << :ac_unrestrict << :ac_safe_conditions
  end
end
