module AccessControl::Model
  class Node < ActiveRecord::Base

    set_table_name :ac_nodes

    belongs_to :securable, :polymorphic => true

    has_and_belongs_to_many(
      :parents,
      :foreign_key => :node_id,
      :association_foreign_key => :parent_id,
      :class_name => name,
      :join_table => :ac_parents,
      :after_add => :connect_to,
      :after_remove => :disconnect_from
    )

    has_and_belongs_to_many(
      :children,
      :foreign_key => :parent_id,
      :association_foreign_key => :node_id,
      :class_name => name,
      :join_table => :ac_parents
    )

    has_and_belongs_to_many(
      :ancestors,
      :foreign_key => :descendant_id,
      :association_foreign_key => :ancestor_id,
      :class_name => name,
      :join_table => :ac_paths
    )

    has_and_belongs_to_many(
      :descendants,
      :foreign_key => :ancestor_id,
      :association_foreign_key => :descendant_id,
      :class_name => name,
      :join_table => :ac_paths
    )

    has_and_belongs_to_many(
      :strict_ancestors,
      :foreign_key => :descendant_id,
      :association_foreign_key => :ancestor_id,
      :class_name => name,
      :join_table => :ac_paths,
      :conditions => "descendant_id != ancestor_id"
    )

    has_many(
      :principal_assignments,
      :foreign_key => :node_id,
      :class_name => 'AccessControl::Model::Assignment'
    )

    reflections[:principal_assignments].instance_eval do

      def options
        principal_ids = ::AccessControl.get_security_manager.principal_ids
        principal_ids = principal_ids.first if principal_ids.size == 1
        @options.merge(:conditions => {:principal_id => principal_ids})
      end

      def sanitized_conditions
        # Since our options aren't constant in the reflection life cycle, never
        # cache conditions in this instance (the reflection instance).  So,
        # options are evaluated always. (The default implementation caches the
        # options in a instance variable).
        #
        # It took me a long time debugging to find out why the specs concerning
        # the Node class passed when run in isolation but not when all specs
        # were ran together in a bulk.
        @sanitized_conditions = klass.send(:sanitize_sql, options[:conditions])
      end

    end

    has_many(
      :assignments,
      :foreign_key => :node_id,
      :class_name => 'AccessControl::Model::Assignment',
      :dependent => :destroy
    )

    def self.global
      @global ||= find_by_securable_type_and_securable_id(
        'AccessControlGlobalNode', 0, :readonly => true
      )
    end

    def self.global_id
      global.id
    end

    def self.global_securable_type
      'AccessControlGlobalNode'
    end

    def self.global_securable_id
      0
    end

    def self.create_global_node!
      clear_global_node_cache
      ActiveRecord::Base.connection.execute("
        INSERT INTO `ac_nodes` (`securable_type`, `securable_id`)
        VALUES ('#{global_securable_type}', #{global_securable_id})
      ")
    end

    def self.clear_global_node_cache
      @global = nil
    end

    def has_permission? permission
      ancestors.any? do |node|
        node.principal_assignments.any? do |assignment|
          assignment.role.security_policy_items.any? do |item|
            item.permission_name == permission
          end
        end
      end
    end

    def self.securable?
      false
    end

    before_save :validate_parents!
    before_create :verify_global_node
    after_create :make_self_path
    after_create :make_path_from_global
    after_create :connect_to_parents
    after_save :update_blocking

    private

      def verify_global_node
        raise AccessControl::NoGlobalNode unless self.class.global
      end

      def global?
        [securable_type, securable_id] == [
          self.class.global_securable_type,
          self.class.global_securable_id
        ]
      end

      def is_valid_parent? parent
        parent != self.class.global
      end

      def validate_parent! parent
        if global? || !is_valid_parent?(parent)
          raise ::AccessControl::ParentError
        end
      end

      def validate_parents!
        parents.each{|parent| validate_parent!(parent)}
      end

      def make_self_path
        self.class.connection.execute(
          "INSERT INTO `ac_paths` (`ancestor_id`, `descendant_id`) "\
          "VALUES (#{id}, #{id})",
          "#{self.class.name} Create self-path"
        )
      end

      def make_path_from_global
        self.class.connection.execute(
          "INSERT INTO `ac_paths` (`ancestor_id`, `descendant_id`) "\
          "VALUES (#{self.class.global_id}, #{id})",
          "#{self.class.name} Create path to global node"
        )
      end

      def update_blocking
        if block
          disconnect_self_and_descendants_from_ancestors
        else
          connect_to_parents
        end
      end

      def disconnect_from parent
        reconnect_to_parents
      end

      def connect_to_parents
        parents.each{|parent| connect_to(parent)}
      end

      def reconnect_to_parents
        disconnect_self_and_descendants_from_ancestors
        connect_to_parents unless block
      end

      def disconnect_self_and_descendants_from_ancestors
        ancestor_ids = (
          strict_ancestor_ids - [self.class.global_id]
        ).map{|i| i.to_s}.join(',')
        return unless ancestor_ids != ''
        # Include the self id in descendants if it is not included, because it
        # may have been excluded if this node is being removed.
        descendant_ids = (self.descendant_ids | [id]).map{|i| i.to_s}.join(',')
        self.class.connection.execute(
          "DELETE FROM `ac_paths` "\
          "WHERE `ancestor_id` IN (#{ancestor_ids}) "\
            "AND `descendant_id` IN (#{descendant_ids})",
          "#{self.class.name} Disconnect from tree"
        )
      end

      def connect_to parent
        validate_parent!(parent)
        return if block || new_record?
        copy_ancestors_from parent
        cascade_ancestors_to_descendants
      end

      def copy_ancestors_from node
        if node.respond_to?(:map)
          nodes = node.map(&(:id.to_proc)).map(&(:to_s.to_proc)).join(',')
          self.class.connection.execute(
            "INSERT IGNORE INTO `ac_paths` (`ancestor_id`, `descendant_id`) "\
              "SELECT `ancestor_id`, #{id} FROM `ac_paths` "\
              "WHERE `descendant_id` IN (#{nodes})",
            "#{self.class.name} Copy ancestors"
          )
        else
          self.class.connection.execute(
            "INSERT IGNORE INTO `ac_paths` (`ancestor_id`, `descendant_id`) "\
              "SELECT `ancestor_id`, #{id} FROM `ac_paths` "\
              "WHERE `descendant_id` = #{node.id}",
            "#{self.class.name} Copy ancestors"
          )
        end
      end

      def cascade_ancestors_to_descendants
        self.class.connection.execute(
          "INSERT INTO `ac_paths` (`ancestor_id`, `descendant_id`) "\
            "SELECT `anc`.`ancestor_id`, `desc`.`descendant_id` "\
            "FROM `ac_paths` AS `anc`, `ac_paths` AS `desc` "\
            "WHERE ("\
              "`anc`.`descendant_id` = #{id} "\
                "AND `anc`.`ancestor_id` != #{id} "\
              "AND `anc`.`ancestor_id` != #{self.class.global_id}"\
            ") AND ("\
              "`desc`.`ancestor_id` = #{id} "\
                "AND `desc`.`descendant_id` != #{id} "\
            ") AND `anc`.`ancestor_id` NOT IN ("\
              "SELECT `ancestor_id` FROM `ac_paths` "\
              "WHERE `descendant_id`= `desc`.`descendant_id`"\
            ")",
          "#{self.class.name} Cascade ancestors to descendants"
        )
      end

  end
end
