module AccessControl
  class AssignmentCombination
    include Enumerable

    def each(&block)
      if block_given?
        combinations.each do |combination|
          block.call instance_for(combination)
        end
        @instances.values_at(*combinations)
      else
        Enumerator.new do |yielder|
          combinations.each do |combination|
            yielder.yield instance_for(combination)
          end
        end
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
          @instances = nil                   #    @instances = nil
          @#{property}_ids = normalize(ids)  #    @roles_ids = normalize(ids)
        end                                  #  end
                                             #
        alias_method :#{singular}_id=,       #  alias_method :role_id=,
                       :#{property}_ids=     #                 :role_ids=
                                             #
        def #{property}=(values)             #  def roles=(values)
          @instances = nil                   #    @instances = nil
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

    def instance_for(combination)
      @instances ||= {}
      @instances[combination] ||= begin
        existing_assignments[combination] || new_assignment(*combination)
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
      roles      = roles_ids.to_a
      principals = principals_ids.to_a
      nodes      = nodes_ids.to_a

      combinations = roles.product(principals, nodes)
      if include_existing_assignments
        combinations
      else
        old_combinations = existing_assignments.keys
        combinations.reject { |c| old_combinations.include?(c) }
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
