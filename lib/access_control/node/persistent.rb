require 'access_control/node'

module AccessControl
  class Node::Persistent < ActiveRecord::Base
    set_table_name 'ac_nodes'

    extend AccessControl::Ids

    named_scope :with_type, lambda {|securable_type| {
      :conditions => { :securable_type => securable_type }
    }}
  end
end
