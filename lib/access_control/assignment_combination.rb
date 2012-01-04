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

    def size
      combinations.size
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

    attr_writer :skip_existing_assigments
    def skip_existing_assigments
      !!@skip_existing_assigments
    end

    attr_writer :only_existing_assigments
    def only_existing_assigments
      !!@only_existing_assigments
    end

  private

    def clear_memoizations
      @instances = nil
      @existing_assignments = nil
      @existing_combinations = nil
      @combinations = nil
    end

    def instances
      @instances ||= {}
    end

    def instance_for(ids)
      instances[ids.to_s] ||=
        existing_assignment(*ids) || new_assignment(*ids)
    end

    def existing_assignment(role_id, principal_id, node_id)
      existing_assignments[role_id][principal_id][node_id]
    end

    def existing_assignments
      @existing_assignments ||= begin
        Hash.new do |tree, role_id|
          tree[role_id] = Hash.new do |subtree, principal_id|
            assignments = Assignment.overlapping(role_id, principal_id, nodes_ids)
            subtree[principal_id] = assignments.index_by(&:node_id)
          end
        end
      end
    end

    def new_assignment(role_id, principal_id, node_id)
      Assignment.new(:role_id => role_id, :node_id => node_id,
                     :principal_id => principal_id)
    end

    def combinations
      @combinations ||=
        begin
          combinations = roles_ids.product(principals_ids, nodes_ids)

          if skip_existing_assigments
            combinations = combinations - existing_combinations
          end

          if only_existing_assigments
            combinations = combinations & existing_combinations
          end

          combinations
        end
    end

    def normalize(value)
      if value.kind_of?(Enumerable)
        value
      elsif value.nil?
        []
      else
        [value]
      end
    end

    def normalize_instances(value)
      unless value.kind_of?(Enumerable)
        value = Array(value)
      end

      value.map(&:id)
    end

    def existing_combinations
      @existing_combinations ||= existing_assignments.keys
    end
  end
end
