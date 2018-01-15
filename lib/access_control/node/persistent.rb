require 'access_control'
require 'access_control/dataset_helper'
require 'access_control/util'

module AccessControl
  class Node
    class Persistent < Sequel::Model(:ac_nodes)
      include AccessControl::DatasetHelper

      dataset_module do
        def blocked
          filter(block: true)
        end

        def with_type(securable_type)
          filter(securable_type: securable_type)
        end

        def with_securable_id(ids)
          filter(securable_id: ids)
        end

        def for_securables(securables)
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

        def ancestors_of(*args)
          ac_nodes = AccessControl.ac_nodes
          ac_parents = AccessControl.ac_parents

          if args.first.is_a?(Sequel::Dataset)
            anchor = args.first.select(:id)
          else
            ids = args.flatten.map do |a|
              Util.id_of(a) { AccessControl::Node(a) }
            end
            anchor = ac_nodes.select(:id).where(id: ids)
          end

          with_recursive(
            :ancestors,
            anchor,
            ac_parents.select(:parent_id).join(:ancestors, node_id: :child_id),
            args: %i(node_id),
            union_all: false
          ).where { id =~ AccessControl.db[:ancestors].select(:node_id) }
        end
      end
    end
  end
end
