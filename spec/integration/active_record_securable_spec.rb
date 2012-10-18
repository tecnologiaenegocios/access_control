require 'spec_helper'

describe "node association" do
  include WithConstants

  let_constant(:ar_object_class) { new_class(:Record, ActiveRecord::Base) }

  let(:ac_object_class)     { AccessControl::Node }
  let(:ac_object_type_attr) { :securable_type }
  let(:ac_object_id_attr)   { :securable_id }

  def ac_object_from_ar_object(ar_object)
    AccessControl::Node(ar_object)
  end

  def include_needed_modules(klass)
    klass.class_eval do
      include AccessControl::Securable
      requires_no_permissions!
    end
  end

  it_should_behave_like "any AccessControl object associated with an ActiveRecord::Base"
end
