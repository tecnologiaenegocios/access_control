module AccessControl

  class Error < StandardError
  end

  class Unauthorized                 < Error; end
  class NoGlobalNode                 < Error; end
  class NoContextError               < Error; end
  class InvalidInheritage            < Error; end
  class MissingPermissionDeclaration < Error; end
  class CannotRestrict               < Error; end
  class InvalidSubject               < Error; end
  class UnrecognizedSecurable        < Error; end
end
