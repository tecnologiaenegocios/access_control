require 'access_control/exceptions'

module AccessControl
  module Inheritance

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods

      def inherits_permissions_from *args
        @__inheritance__ =
          if args.any?
            args.flatten.inject([]) do |items, assoc|
              assoc = assoc.to_sym
              klass = reflections[assoc].klass
              raise InvalidInheritage unless klass.include?(Restriction)
              items << assoc
            end
          else
            @__inheritance__ || []
          end
      end

      def parent_models_and_options
        AccessControl.security_manager.without_query_restriction do
          inherits_permissions_from.inject([]) do |items, assoc|
            model = reflections[assoc].klass
            pk = model.primary_key
            select = "DISTINCT #{model.quoted_table_name}.#{pk}"
            ids = find(:all, :select => select, :joins => assoc).
              map(&(pk.to_sym.to_proc))
            items << [model, assoc, Set.new(ids)]
          end
        end
      end

    end

  end
end
