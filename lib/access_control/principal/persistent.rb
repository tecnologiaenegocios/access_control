require 'access_control'
require 'access_control/dataset_helper'

module AccessControl
  class Principal
    class Persistent < Sequel::Model(:ac_principals)
      include AccessControl::DatasetHelper
    end
  end
end
