require 'access_control/registry_factory'

module AccessControl
  Registry = RegistryFactory.new
  Registry.add_collection_index(:ac_methods)
  Registry.add_collection_index(:ac_classes)

  def Registry.permissions_for(class_name, method_name)
    query(:ac_methods => [[class_name, method_name.to_sym]])
  end
end
