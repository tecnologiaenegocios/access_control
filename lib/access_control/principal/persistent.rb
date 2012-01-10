require 'access_control'

module AccessControl
  class Principal
    class Persistent < Sequel::Model(:ac_principals)
      include AccessControl::DatasetHelper
    end
  end
end
