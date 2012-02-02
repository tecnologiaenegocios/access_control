module Spec::Mocks::ArgumentMatchers
  def collection(*collection)
    include_only(*collection)
  end
  alias_method :collection_including, :collection
end
