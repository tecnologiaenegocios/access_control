module ActiveSupport
  module TimeZoneRuby22Patches

    # On the original file, this method has a circular reference on the default
    # argument:
    #
    #   def parse(str, now = now)
    #     ...
    #
    # The behavior for the default case has changed on Ruby 2.2.0. Before, this
    # would call the 'now' method on 'self', but for ruby >= 2.2.0 the 'now'
    # argument will be always set to nil. The fix is trivial: use a different
    # argument name.
    def parse(str, time = now)
      super(str, time)
    end
  end

  class TimeZone
    prepend TimeZoneRuby22Patches
  end
end

module ActiveRecord
  module BaseRuby22ClassPatches
    # See comment above
    def class_name(table_name = self.table_name)
      super(table_name)
    end
  end

  Base.instance_eval do
    singleton_class.prepend BaseRuby22ClassPatches
  end
end
