module AccessControl
  module Util
    def make_set_from_args *args
      if args.size == 1 && args.first.is_a?(Enumerable)
        return Set.new(args.first)
      end
      Set.new(args)
    end
  end
end
