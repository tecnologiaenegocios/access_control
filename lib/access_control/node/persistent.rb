require 'access_control'
require 'access_control/dataset_helper'

module AccessControl
  class Node
    class Persistent < Sequel::Model(:ac_nodes)
      include AccessControl::DatasetHelper

      def_dataset_method(:with_type) do |securable_type|
        filter(:securable_type => securable_type)
      end
    end
  end
end
