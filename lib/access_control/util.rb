module AccessControl
  module Util
    class << self

      # An utility method that wraps the following common patterns:
      #
      # collection.inject(Set.new, &:add)
      # collection.inject(Set.new) { |set, foo| set.add foo.bar }
      # collection.inject(Set.new) { |set, foo| set.merge foo.bars }.flatten
      #
      # On the following:
      #
      # Util.flat_set(enumerable)
      # Util.flat_set(enumerable, &:foo)
      # Util.flat_set(enumerable, &:foos)
      #
      # Check out the specs for more specific examples.

      def flat_set(enumerable, &block)
        collection = block ? enumerable.map(&block) : enumerable

        collection.inject(Set.new) do |set, element|
          if element.kind_of?(Enumerable) && !element.kind_of?(Hash)
            set.merge element
          else
            set.add element
          end
        end
      end

      # Has the same behavior as Util.flat_set, but removes nil values from
      # the result. Example:
      #
      # collection = [1, nil, 3, 4, nil]
      #
      # Util.flat_set(collection)
      # => #<Set: {1, nil, 3, 4}>
      #
      # Util.compact_flat_set(collection)
      # => #<Set: {1, 3, 4}>

      def compact_flat_set(enumerable, &block)
        set = flat_set(enumerable, &block)
        set.reject!(&:nil?)

        set
      end

      # Return an id from an object, or the object itself if it is a Fixnum.
      def id_of(object)
        if object.nil?
          nil
        elsif object.is_a?(Fixnum)
          object
        elsif block_given?
          id_of(yield)
        else
          object.id
        end
      end

      # Return one or more ids suitable for a hash condition, or nil if
      # argument is empty.  Example:
      #
      # Util.ids_for_hash_condition(nil)
      # => nil
      #
      # Util.ids_for_hash_condition(1)
      # => 1
      #
      # Util.ids_for_hash_condition([1])
      # => 1
      #
      # Util.ids_for_hash_condition([1, 2])
      # => [1, 2]
      #
      # Util.ids_for_hash_condition([])
      # => []
      #
      # Also works with sets instead of arrays.

      def ids_for_hash_condition(items)
        return nil if items.nil?

        items = Array(items)
        items = items.map do |item|
          id_of(item)
        end

        case items.size
        when 1 then items.first
        else items
        end
      end

      def make_set_from_args *args
        if args.size == 1 && args.first.is_a?(Enumerable)
          return Set.new(args.first)
        end
        Set.new(args)
      end

      def prettify_sql(sql)
        sql.gsub(/^\s*/, '').gsub(/\n\s*/, '')
      end

      # Platform checks
      # ---------------

      # Test if Class#new calls Class#allocate when Class#allocate is
      # overridden.
      #
      # In some Ruby implementations, like Rubinius, .new calls .allocate even
      # if it is overridden, unlike in MRI where .new calls only the C
      # implementation of #allocate (effectively skipping the overriding
      # implementation).  So in the platforms where .new calls the overridden
      # .allocate we don't do our dark wizardry for instance creation twice,
      # since it is enough to do it by overriding .allocate.  On the other
      # hand, if .new only calls the low-level implementation directly, we need
      # to do our magic in .allocate and in .new as well.
      #
      # But why the hell one wants to override .allocate?  Isn't .new just as
      # good?  Unfortunatelly no, because ActiveRecord calls .allocate to
      # create instances from .find, and even then we want our funny tricks
      # working.
      def new_calls_allocate?
        return @new_calls_allocate unless @new_calls_allocate.nil?
        @new_calls_allocate = false
        klass = Class.new do
          def self.allocate
            AccessControl::Util.new_calls_allocate!
            super
          end
        end
        klass.new
        @new_calls_allocate
      end

      def new_calls_allocate!
        @new_calls_allocate = true
      end
    end
  end
end
