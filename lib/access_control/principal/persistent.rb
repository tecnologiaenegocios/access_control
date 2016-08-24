require 'access_control/db'

module AccessControl
  class Principal
    class Persistent < Sequel::Model(:ac_principals)
    end
  end
end
