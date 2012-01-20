require 'access_control/manager'
require 'access_control/securable'
require 'access_control/inheritance'

module AccessControl

  MANAGER_THREAD_KEY = :ac_manager

  def self.manager
    Thread.current[MANAGER_THREAD_KEY] ||= Manager.new
  end

  def self.no_manager
    Thread.current[MANAGER_THREAD_KEY] = nil
  end

  def self.global_node_id
    global_node.id
  end

  def self.global_node
    Node.global
  end

  def self.global_securable_type
    GlobalRecord.name
  end

  def self.global_securable_id
    GlobalRecord.instance.id
  end

  def self.anonymous_id
    anonymous.id
  end

  def self.anonymous
    Principal.anonymous
  end

  def self.anonymous_subject_type
    AnonymousUser.name
  end

  def self.anonymous_subject_id
    AnonymousUser.instance.id
  end

  def self.setup_parent_relationships(securable_class)
    AccessControl.transaction do

      Inheritance.inheritances_of(securable_class).each do |inheritance|
        relationships = inheritance.relationships

        if relationships.kind_of?(Sequel::Dataset)
          existing = ac_parents.filter([:parent_id, :child_id] => relationships)
          existing.delete

          ac_parents.import([:parent_id, :child_id], relationships)
        else
          tuples   = relationships.map { |r| [r[:parent_id], r[:child_id]] }
          existing = ac_parents.filter([:parent_id, :child_id] => tuples)
          existing.delete

          ac_parents.multi_insert(inheritance.relationships)
        end
      end

    end
  end

  class GlobalRecord
    include Singleton
    include Securable
    def id
      1
    end
  end

  class AnonymousUser
    include Singleton
    def id
      1
    end
  end
end
