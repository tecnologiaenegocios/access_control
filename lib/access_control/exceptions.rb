module AccessControl

  class Unauthorized < StandardError
  end

  class NoGlobalNode < StandardError
  end

  class NoContextError < StandardError
  end

  class InvalidInheritage < StandardError
  end

  class MissingPermissionDeclaration < StandardError
  end

  class CannotRestrict < StandardError
  end

  class InvalidSubject < StandardError
  end

end
