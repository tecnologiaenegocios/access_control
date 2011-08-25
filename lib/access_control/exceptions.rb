module AccessControl

  class Unauthorized < StandardError
  end

  class ParentError < StandardError
  end

  class NoGlobalNode < StandardError
  end

  class CannotWrapUnsecurableObject < StandardError
  end

  class NoSecurityContextError < StandardError
  end

  class InvalidInheritage < StandardError
  end

  class InvalidPropagation < StandardError
  end

  class MissingPropagation < StandardError
  end

  class MissingPermissionDeclaration < StandardError
  end

  class CannotRestrict < StandardError
  end

end
