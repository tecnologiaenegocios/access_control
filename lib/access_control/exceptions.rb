module AccessControl

  class Error < StandardError
  end

  class Unauthorized                 < Error; end
  class NoGlobalNode                 < Error; end
  class NoAnonymousPrincipal         < Error; end
  class NoContextError               < Error; end
  class InvalidInheritage            < Error; end
  class MissingPermissionDeclaration < Error; end
  class CannotRestrict               < Error; end
  class UnrecognizedSecurable        < Error; end
  class UnrecognizedSubject          < Error; end
  class NotFoundError                < Error; end
  class RecordNotPersisted           < Error; end
end
