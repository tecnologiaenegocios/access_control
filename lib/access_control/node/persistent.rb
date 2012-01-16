require 'access_control'
require 'access_control/dataset_helper'

module AccessControl
  class Node
    class Persistent < Sequel::Model(:ac_nodes)
      include AccessControl::DatasetHelper

      def_dataset_method(:with_type) do |securable_type|
        filter(:securable_type => securable_type)
      end

      def_dataset_method(:with_securable_id) do |ids|
        filter(:securable_id => ids)
      end

      def_dataset_method(:for_securables) do |securables|
        securables = Array(securables)

        types_and_ids = securables.map { |s| [s.class.name, s.id] }

        filter([:securable_type, :securable_id] => types_and_ids)
      end
    end
  end
end
