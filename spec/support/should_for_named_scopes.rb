if defined?(ActiveRecord::NamedScope::Scope)
  class ActiveRecord::NamedScope::Scope
    remove_method :should, :should_not
  end
end
