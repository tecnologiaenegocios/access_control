module AccessControl
  class AssignmentCombination
    include Enumerable

    def each
      return to_enum(:each) unless block_given?

      combinations.map do |combination|
        instance_for(combination).tap { |i| yield i }
      end
    end

    def all
      each.to_a
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
          clear_memoizations                 #    clear_memoizations
          @#{property}_ids = normalize(ids)  #    @roles_ids = normalize(ids)
        end                                  #  end
                                             #
        alias_method :#{singular}_id=,       #  alias_method :role_id=,
                       :#{property}_ids=     #                 :role_ids=
                                             #
        def #{property}=(values)             #  def roles=(values)
          clear_memoizations                 #    clear_memoizations
          @#{property}_ids =                 #    @roles_ids =
            normalize_instances(values)      #      normalize_instances(values)
        end                                  #  end
                                             #
        alias_method :#{singular}=,          #  alias_method :role=,
                       :#{property}=         #                 :roles=
      CODE
    end

    attr_writer :include_existing_assignments
    def include_existing_assignments
      if @include_existing_assignments.nil?
        true
      else
        @include_existing_assignments
      end
    end

  private

    def clear_memoizations
      @instances = nil
      @existing_assignments = nil
      @combinations = nil
    end

    def instances
      @instances ||= {}
    end

    def instance_for(combination)
      instances[combination] ||= begin
        if include_existing_assignments
          existing_assignments[combination] || new_assignment(*combination)
        else
          new_assignment(*combination)
        end
      end
    end

    def existing_assignments
      @existing_assignments ||= begin
        assignments = Assignment.overlapping(roles_ids, principals_ids, nodes_ids)
        assignments.index_by { |a| [a.role_id, a.principal_id, a.node_id] }
      end
    end

    def new_assignment(role_id, principal_id, node_id)
      Assignment.new(:role_id => role_id, :node_id => node_id,
                     :principal_id => principal_id)
    end

    def combinations
      @combinations ||= begin
        roles      = roles_ids.to_a
        principals = principals_ids.to_a
        nodes      = nodes_ids.to_a

        combinations = Set.new(roles.product(principals, nodes))
        if include_existing_assignments
          combinations
        else
          old_combinations = Set.new(existing_assignments.keys)
          combinations.subtract(old_combinations)
        end
      end
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
