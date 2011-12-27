module AccessControl
  class AssignmentCombination
    include Enumerable

    def each(&block)
      all.each(&block)
    end

    def all
      @results ||= Util.flat_set(combinations) do |combination|
        new_assignment = new_assignment(*combination)

        existing_assignment = existing_assignments.detect do |assignment|
          assignment.overlaps?(new_assignment)
        end

        existing_assignment || new_assignment
      end
    end

    def initialize(properties = {})
      properties.each do |property, value|
        public_send("#{property}=", value)
      end
    end

    properties = %w[roles principals nodes]
    properties.each do |property|
      singular = property.singularize

      class_eval(<<-CODE, __FILE__, __LINE__+1)
        attr_reader :#{property}_ids         #  attr_reader :roles_ids
                                             #
        def #{property}_ids=(ids)            #  def roles_ids=(ids)
          @results = nil                     #    @results = nil
          @#{property}_ids = normalize(ids)  #    @roles_ids = normalize(ids)
        end                                  #  end
                                             #
        alias_method :#{singular}_id=,       #  alias_method :role_id=,
                       :#{property}_ids=     #                 :role_ids=
                                             #
        def #{property}=(values)             #  def roles=(values)
          @results = nil                     #    @results = nil
          @#{property}_ids =                 #    @roles_ids =
            normalize_instances(values)      #      normalize_instances(values)
        end                                  #  end
                                             #
        alias_method :#{singular}=,          #  alias_method :role=,
                       :#{property}=         #                 :roles=
      CODE
    end

    private

    def existing_assignments
      @existing_assignments ||=
        Assignment.overlapping(roles_ids, principals_ids, nodes_ids)
    end

    def new_assignment(role_id, principal_id, node_id)
      Assignment.new(:role_id => role_id, :node_id => node_id,
                     :principal_id => principal_id)
    end

    def combinations
      roles      = roles_ids.to_a
      principals = principals_ids.to_a
      nodes      = nodes_ids.to_a

      roles.product(principals, nodes)
    end

    def normalize(value)
      if value.kind_of?(Enumerable)
        value
      elsif value.nil?
        Set.new
      else
        Set[value]
      end
    end

    def normalize_instances(value)
      unless value.kind_of?(Enumerable)
        value = Array(value)
      end

      Util.compact_flat_set(value, &:id)
    end

  end
end
