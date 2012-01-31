require 'access_control/registry_factory'

module AccessControl
  Registry = RegistryFactory.new
  Registry.add_collection_index(:ac_methods)
  Registry.add_collection_index(:ac_classes)
end
