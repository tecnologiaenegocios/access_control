module AccessControl

  class Error < StandardError
  end

  class NoGlobalNode                 < Error; end
  class NoAnonymousPrincipal         < Error; end
  class InvalidContextDesignator     < Error; end
  class NoContextError               < Error; end
  class InvalidInheritage            < Error; end
  class MissingPermissionDeclaration < Error; end
  class CannotRestrict               < Error; end
  class UnrecognizedSecurable        < Error; end
  class UnrecognizedSubject          < Error; end
  class NotFoundError                < Error; end
  class RecordNotPersisted           < Error; end

  class Unauthorized < Error
    def initialize(args=nil)
      args = [[], []] unless args
      permissions, context = args
      @permissions, @context = Array(permissions), Array(context)
    end

    def to_s
      if @permissions.any? && @context.any?
        "Missing #{@permissions.map(&:name).join(', ')} on #{
          @context.map(&:inspect).join(', ')}"
      else
        super
      end
    end
  end
end
