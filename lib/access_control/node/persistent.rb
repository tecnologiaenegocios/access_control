require 'access_control'

module AccessControl
  class Node
    class Persistent < Sequel::Model(:ac_nodes)
      def_dataset_method(:blocked) do
        filter(block: true)
      end

      def_dataset_method(:with_type) do |securable_type|
        filter(securable_type: securable_type)
      end

      def_dataset_method(:with_securable_id) do |ids|
        filter(securable_id: ids)
      end

      def_dataset_method(:for_securables) do |securables|
        securables = Array(securables)

        filters = securables.group_by(&:class).map do |klass, group|
          { securable_type: klass.name, securable_id: group.map(&:id) }
        end

        if filters.any?
          filter(filters.inject { |acc, filter| Sequel.|(acc, filter) })
        else
          exclude { id == id }
        end
      end
    end
  end
end
